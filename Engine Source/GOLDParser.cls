VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "GOLDParser"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'===================================================================
' Class Name:
'    GOLDParser (basic version)
'
' Instancing:
'      Public; Creatable  (VB Setting: 5 - MultiUse)
'
' Purpose:
'    This is the main class in the GOLD Parser Engine and is used to perform
'    all duties required to the parsing of a source text string. This class
'    contains the LALR(1) State Machine code, the DFA State Machine code,
'    character table (used by the DFA algorithm) and all other structures and
'    methods needed to interact with the developer.
'
'Author(s):
'   Devin Cook
'
'Public Dependencies:
'   Token, Rule, Symbol, Reduction
'
'Private Dependencies:
'   ObjectList, SimpleDatabase, SymbolList, StringList, VariableList, TokenStack
'
'Revision History:
'   June 9, 2001:
'      Added the ReductionMode property and modified the Reduction object (which was
'      used only for internal use). In addition the Reduction property was renamed to
'      CurrentReduction to avoid possible name conflicts in different programming languages
'      (which this VB source will be converted to eventually)
'   Sept 5, 2001:
'      I was alerted to an error in the engine logic by Szczepan Holyszewski [rulatir@poczta.arena.pl].
'      When reading tokens inside a block quote, the line-comment token would still eliminate the rest
'      of a line - possibly eliminating the block quote end.
'   Nov 28, 2001:
'      Fixed several errors.
'   December 2001:
'      Added the TrimReductions property and required logic
'===================================================================


'================================================================================
'
'                 The GOLD Parser Freeware License Agreement
'                 ==========================================
'
'this software Is provided 'as-is', without any expressed or implied warranty.
'In no event will the authors be held liable for any damages arising from the
'use of this software.
'
'Permission is granted to anyone to use this software for any purpose. If you
'use this software in a product, an acknowledgment in the product documentation
'would be deeply appreciated but is not required.
'
'In the case of the GOLD Parser Engine source code, permission is granted to
'anyone to alter it and redistribute it freely, subject to the following
'restrictions:
'
'   1. The origin of this software must not be misrepresented; you must not
'      claim that you wrote the original software.
'
'   2. Altered source versions must be plainly marked as such, and must not
'      be misrepresented as being the original software.
'
'   3. This notice may not be removed or altered from any source distribution
'
'================================================================================

'================================================================================
'===================== http://www.DevinCook.com/GOLDParser  =====================
'================================================================================

Option Explicit


Private pSymbolTable As New ObjectList     'Symbols recognized by the system

Private pDFA As New ObjectList             'DFA. Contains FAStates.

Private pCharacterSetTable As New StringList

Private pRuleTable As New ObjectList       'Rules. Contains Rule Objects.

Private pVariables As New VariableList     'Grammar parameters

Private pActionTable As New ObjectList     'LALR(1) action table. Contains LRActionTables.


'================================== Parsing messages
Public Enum GPMessageConstants
   gpMsgTokenRead = 1               'A new token is read
   gpMsgReduction = 2               'A rule is reduced
   gpMsgAccept = 3                  'Grammar complete
   gpMsgNotLoadedError = 4          'Now grammar is loaded
   gpMsgLexicalError = 5            'Token not recognized
   gpMsgSyntaxError = 6             'Token is not expected
   gpMsgCommentError = 7            'Reached the end of the file - mostly due to being stuck in comment mode
   gpMsgInternalError = 8           'Something is wrong, very wrong
End Enum
  
'========================================= DFA runtime constants
Private kErrorSymbol As Symbol
Private kEndSymbol As Symbol

'========================================= DFA runtime variables
Private InitialDFAState As Integer

'========================================= LALR runtime variables
Private InitialLALRState As Integer
Private StartSymbol As Integer
Private CurrentLALR As Integer
Private Stack As New TokenStack

'===================== Used for Reductions & Errors
Private pTokens         As New TokenStack        'The set of tokens for 1. Expecting during error, 2. Reduction
Private pHaveReduction  As Boolean

'===================== Properties
'NEW 12/2001
Private pTrimReductions   As Boolean

'===================== Private control variables
Private pTablesLoaded     As Boolean
Private pInputTokens      As New TokenStack        'Stack of tokens to be analyzed
Private pSource           As New LookaheadStream
Private pLineNumber       As Long                  'Incremented by tokenizer
Private pCommentLevel     As Integer               'Current level of block comments (1+)
Private pCompareMode      As VbCompareMethod

'===== NEW 12/2001: This enumerated data type will be used internally.
'===== The ParseToken() function returns this value
Private Enum ParseResultConstants
    ParseResultAccept = 1
    ParseResultShift = 2
    ParseResultReduceNormal = 3
    ParseResultReduceEliminated = 4
    ParseResultSyntaxError = 5
    ParseResultInternalError = 6
End Enum


'============================================== Used to ID rows in the SimpleDatabase file
Private Const RecordIdParameters  As Byte = 80   'P
Private Const RecordIdTableCounts As Byte = 84   'T
Private Const RecordIdInitial     As Byte = 73   'I
Private Const RecordIdSymbols     As Byte = 83   'S
Private Const RecordIdCharSets    As Byte = 67   'C
Private Const RecordIdRules       As Byte = 82   'R
Private Const RecordIdDFAStates   As Byte = 68   'D
Private Const RecordIdLRTables    As Byte = 76   'L
Private Const RecordIdComment     As Byte = 33   '!
Private Const FileHeader = "GOLD Parser Tables/v1.0"
Public Function CurrentLineNumber() As Long

   CurrentLineNumber = pLineNumber

End Function






Public Sub CloseFile()

   pSource.CloseFile

End Sub

Public Function CurrentToken() As Token

   Set CurrentToken = pInputTokens.Top

End Function


Private Sub DiscardRestOfLine()
   Dim sTemp As String

   'Kill the current line - basically for line comments
   sTemp = pSource.ReadLine
   
   '01/26/2002: Fixed bug. Inc counter
   pLineNumber = pLineNumber + 1
End Sub





Public Function PopInputToken() As Token

   Set PopInputToken = pInputTokens.Pop

End Function

Private Sub PrepareToParse()
   'Added 12/23/2001: The token stack is empty until needed
   Dim Start As New Token
   
   Start.State = InitialLALRState
   Set Start.ParentSymbol = pSymbolTable.Member(StartSymbol)
   
   Stack.Push Start

End Sub

Public Sub PushInputToken(TheToken As Token)

   pInputTokens.Push TheToken

End Sub



'Public Function ReduceRule() As Rule

'   If pReduceRule >= 0 And pReduceRule < RuleTable.Count Then
'      Set ReduceRule = pRuleTable.Member(pReduceRule)
'   End If

'End Function


Public Property Get CurrentReduction() As Reduction
    If pHaveReduction Then
        Set CurrentReduction = Stack.Top.Data
    Else
        Set CurrentReduction = Nothing
    End If
End Property


Public Property Set CurrentReduction(Value As Reduction)
    If pHaveReduction Then
        Set Stack.Top.Data = Value
    End If
End Property

Public Sub ShowAboutWindow()

   MsgBox "Put your code to open an 'About Window' here."

End Sub

Public Sub Clear()

   pSymbolTable.Clear
   pRuleTable.Clear
   pCharacterSetTable.Clear
   pVariables.ClearValues
   pTokens.Clear
   pInputTokens.Clear
   
   Reset
End Sub



Public Property Let TrimReductions(Value As Boolean)
    'Added 12/2001
    pTrimReductions = Value
End Property

Public Property Get TrimReductions() As Boolean
    'Added 12/2001
    TrimReductions = pTrimReductions
End Property
Public Function Parameter(Name As String) As String

   Parameter = pVariables.Value(Name)

End Function




Private Function LoadTables(FileName As String) As Boolean
   '== This procedure loads a Compiled Grammar Table file using
   '== the SimpleDatabase object to handle the file structure.
      
   Dim File As New SimpleDataBase, Id As Integer, bAccept As Boolean, n As Integer
   Dim ReadSymbol As Symbol, ReadRule As Rule
   Dim ReadDFA As FAState, ReadLALR As LRActionTable
   Dim Success As Boolean
   
   pVariables.Add "Name"
   pVariables.Add "Version"
   pVariables.Add "Author"
   pVariables.Add "About"
   pVariables.Add "Case Sensitive"
   pVariables.Add "Start Symbol"
   
   Success = True
   File.FileType = FileHeader
   If File.OpenFile(FileName) Then
       Do Until File.Done() Or Success = False
           Success = File.GetNextRecord
           Id = File.RetrieveNext()                   'ID is the first field
               
           Select Case Id
           Case RecordIdParameters                    'Name, Version, Author, About, Case-Sensitive
               pVariables.Value("Name") = File.RetrieveNext
               pVariables.Value("Version") = File.RetrieveNext
               pVariables.Value("Author") = File.RetrieveNext
               pVariables.Value("About") = File.RetrieveNext
               pVariables.Value("Case Sensitive") = File.RetrieveNext
               StartSymbol = CInt(File.RetrieveNext)
               
               pVariables.Value("Start Symbol") = StartSymbol
              
           Case RecordIdTableCounts                   'Symbol, CharacterSet, Rule, DFA, LALR
               pSymbolTable.ReDimension Val(File.RetrieveNext)
               pCharacterSetTable.ReDimension Val(File.RetrieveNext)
               pRuleTable.ReDimension Val(File.RetrieveNext)
               pDFA.ReDimension Val(File.RetrieveNext)
               pActionTable.ReDimension Val(File.RetrieveNext)
            
           Case RecordIdInitial                       'DFA, LALR
               InitialDFAState = File.RetrieveNext
               InitialLALRState = File.RetrieveNext
                             
           Case RecordIdSymbols                       'Index, Name, Kind
               Set ReadSymbol = New Symbol
               n = File.RetrieveNext
               ReadSymbol.Name = File.RetrieveNext
               ReadSymbol.Kind = File.RetrieveNext
               File.RetrieveNext                      'Empty
            
               ReadSymbol.TableIndex = n
               Set pSymbolTable.Member(n) = ReadSymbol
    
           Case RecordIdCharSets                      'Index, Characters
               n = File.RetrieveNext
               pCharacterSetTable.Member(n) = File.RetrieveNext
                         
           Case RecordIdRules                         'Index, ID#, Reserved, (Symbol#,  ...)
               Set ReadRule = New Rule
               n = File.RetrieveNext
               ReadRule.TableIndex = n
               ReadRule.SetRuleNonterminal pSymbolTable.Member(Val(File.RetrieveNext))
               
               File.RetrieveNext                                                'Reserved
               
               Do Until File.RetrieveDone
                   ReadRule.AddItem pSymbolTable.Member(Val(File.RetrieveNext()))
               Loop
               Set pRuleTable.Member(n) = ReadRule
            
           Case RecordIdDFAStates                     'Index, Accept?, Accept#, Reserved (Edge chars, Target#, Reserved)...
               Set ReadDFA = New FAState
               n = File.RetrieveNext
               bAccept = File.RetrieveNext
               If bAccept Then
                   ReadDFA.AcceptSymbol = File.RetrieveNext
               Else
                   ReadDFA.AcceptSymbol = -1
                   File.RetrieveNext                                            'Discard value
               End If
               File.RetrieveNext                                                'Reserved
            
               Do Until File.RetrieveDone
                   ReadDFA.AddEdge File.RetrieveNext, File.RetrieveNext
                   File.RetrieveNext                                            'Reserved
               Loop
               Set pDFA.Member(n) = ReadDFA
         
           Case RecordIdLRTables                      'Index, Reserved (Symbol#, Action, Target#, Reserved)...
               Set ReadLALR = New LRActionTable
               n = File.RetrieveNext
               File.RetrieveNext                                                'Reserved
               
               Do Until File.RetrieveDone
                   ReadLALR.AddItem pSymbolTable.Member(File.RetrieveNext), File.RetrieveNext, File.RetrieveNext
                   File.RetrieveNext                                            'Reserved
               Loop
               Set pActionTable.Member(n) = ReadLALR
            
           Case Else       'RecordIDComment
               Success = False
           End Select
       Loop
                
       '====== Setup internal variables to reflect the loaded data
       'Reassign the numeric value of the start symbol to its name
       pVariables.Value("Start Symbol") = pSymbolTable.Member(pVariables.Value("Start Symbol")).Name

       File.CloseFile
       LoadTables = Success
   Else
       LoadTables = False
   End If

End Function
Public Function SymbolTableCount() As Integer

   SymbolTableCount = pSymbolTable.Count

End Function

Public Function RuleTableCount() As Integer

   RuleTableCount = pRuleTable.Count

End Function


Public Function SymbolTableEntry(ByVal Index As Integer) As Symbol

   If Index >= 0 And Index < pSymbolTable.Count Then
      Set SymbolTableEntry = pSymbolTable.Member(Index)
   End If

End Function


Public Function RuleTableEntry(ByVal Index As Integer) As Rule

   If Index >= 0 And Index < pRuleTable.Count Then
      Set RuleTableEntry = pRuleTable.Member(Index)
   End If

End Function


Public Function TokenCount() As Integer

   TokenCount = pTokens.Count

End Function


Public Function Tokens(ByVal Index As Integer) As Token

   If Index >= 0 And Index < pTokens.Count Then
      Set Tokens = pTokens.Member(Index)
   Else
      Set Tokens = Nothing
   End If

End Function

Public Function LoadCompiledGrammar(FileName As String) As Boolean
   Reset
   LoadCompiledGrammar = LoadTables(FileName)
End Function

'Private Function LoadTableData()

'On Error Resume Next
'
'Dim Success As Boolean
'
'FileDialog.Flags = cdlOFNHideReadOnly Or cdlOFNOverwritePrompt
'FileDialog.DefaultExtension = FileExtension
'FileDialog.Filter = FileFilter
'FileDialog.DefaultFileName = CreateFileName(Variables.Value("Name"))
'FileDialog.Title = "Please select a name for the file"
'FileDialog.GetFileNameOpen
'
'If FileDialog.FileName = "" Or FileDialog.Cancelled Then
'   MsgBox "File load was canceled"
'   Success = False
'Else
'   Success = LoadTables(FileDialog.FileName)
'
'   If Success Then
'      'MsgBox "The compiled grammar file was successfully loaded"
'   Else
'      'SetStatusMessage "There was an error saving the file. The parser tables are not saved"
'      MsgBox "There was an failure loading the file", vbCritical, "Error loading file"
'   End If
'End If
'
'LoadTableData = Success

'End Function

Public Function OpenTextString(Text As String) As Boolean
   
   Reset
   pSource.Text = Text
   PrepareToParse
   OpenTextString = True

End Function
Public Function Parse() As GPMessageConstants
    '1. If the tables are not setup then report GPM_NotLoadedError
    '2. If parser is in comment mode then read tokens until a recognized one is found and report it
    '3. Otherwise, parse normally
    '   a. If there are no tokens on the stack
    '      1) Read one from the input string
    '      2) If there were no tokens, trap error
    '      3) else end the function with GPM_TokenRead
    '   b. Otherwise, call ParseToken with the top of the stack.
    '      1) If success, then Pop the value
    '      2) Loop if the token was shifted (nothing to report)

    Dim Result As GPMessageConstants, Done As Boolean
    Dim ReadToken As Token, ParseResult As ParseResultConstants
       
    If pActionTable.Count < 1 Or pDFA.Count < 1 Then
        Result = gpMsgNotLoadedError
    Else
        Done = False
        Do Until Done
            If pInputTokens.Count = 0 Then                     'We must read a token
                Set ReadToken = RetrieveToken(pSource)
                If ReadToken Is Nothing Then
                    Result = gpMsgInternalError
                    Done = True
                ElseIf ReadToken.Kind <> SymbolTypeWhitespace Then
                    pInputTokens.Push ReadToken
                    If pCommentLevel = 0 And ReadToken.Kind <> SymbolTypeCommentLine And ReadToken.Kind <> SymbolTypeCommentStart Then
                        Result = gpMsgTokenRead
                        Done = True
                    End If
                End If

            ElseIf pCommentLevel > 0 Then           'We are in a block comment
                Set ReadToken = pInputTokens.Pop()

                Select Case ReadToken.Kind
                Case SymbolTypeCommentStart
                    pCommentLevel = pCommentLevel + 1
                Case SymbolTypeCommentEnd
                    pCommentLevel = pCommentLevel - 1
                Case SymbolTypeEnd
                    Result = gpMsgCommentError
                    Done = True
                Case Else
                    'Do nothing, ignore
                    'The 'comment line' symbol is ignored as well
                End Select
            Else
                '==== We are ready to parse
                Set ReadToken = pInputTokens.Top

                Select Case ReadToken.Kind
                Case SymbolTypeCommentStart
                    pCommentLevel = pCommentLevel + 1
                    pInputTokens.Pop                           'Remove it
                Case SymbolTypeCommentLine
                    pInputTokens.Pop                           'Remove it and rest of line
                    DiscardRestOfLine                          'Procedure also increments the line number
                Case SymbolTypeError
                    Result = gpMsgLexicalError
                    Done = True
                Case Else                                      'FINALLY, we can parse the token
                    ParseResult = ParseToken(ReadToken)
                    'NEW 12/2001: Now we are using the internal enumerated constant
                    Select Case ParseResult
                    Case ParseResultAccept
                        Result = gpMsgAccept
                        Done = True
                    Case ParseResultInternalError
                        Result = gpMsgInternalError
                        Done = True
                    Case ParseResultReduceNormal
                        Result = gpMsgReduction
                        Done = True
                    Case ParseResultShift                      'A simple shift, we must continue
                        pInputTokens.Pop                       'Okay, remove the top token, it is on the stack
                    Case ParseResultSyntaxError
                        Result = gpMsgSyntaxError
                        Done = True
                    Case Else
                        'Do nothing
                    End Select

                End Select
            End If
        Loop
        
    End If
    
    Parse = Result

End Function
Private Function ParseToken(NextToken As Token) As ParseResultConstants
   'This function analyzes a token and either:
   '  1. Makes a SINGLE reduction and pushes a complete Reduction object on the stack
   '  2. Accepts the token and shifts
   '  3. Errors and places the expected symbol indexes in the Tokens list
   'The Token is assumed to be valid and WILL be checked
   'If an action is performed that requires controlt to be returned to the user, the function returns true.
   'The Message parameter is then set to the type of action.
   
   '12/14/2001: Procedure modified to use the ParseActionConstants.
   
   Dim n As Integer, Found As Boolean, Index As Integer, RuleIndex As Integer, CurrentRule As Rule
   Dim str As String, Head As Token, NewReduction As Reduction
   Dim Result As ParseResultConstants
   
      
   Index = pActionTable.Member(CurrentLALR).ActionIndexForSymbol(NextToken.ParentSymbol.TableIndex)
         
   If Index <> -1 Then              'Work - shift or reduce
       pHaveReduction = False       'Will be set true if a reduction is made
       pTokens.Count = 0
   
       Select Case pActionTable.Member(CurrentLALR).Item(Index).Action
       Case ActionAccept
           pHaveReduction = True
           Result = ParseResultAccept
         
       Case ActionShift
           CurrentLALR = pActionTable.Member(CurrentLALR).Item(Index).Value
           NextToken.State = CurrentLALR
           Stack.Push NextToken
           Result = ParseResultShift
   
       Case ActionReduce
           'Produce a reduction - remove as many tokens as members in the rule & push a nonterminal token
           
           RuleIndex = pActionTable.Member(CurrentLALR).Item(Index).Value
           Set CurrentRule = pRuleTable.Member(RuleIndex)
           
           '======== Create Reduction
           If pTrimReductions And CurrentRule.ContainsOneNonTerminal Then
               'NEW 12/2001
               'The current rule only consists of a single nonterminal and can be trimmed from the
               'parse tree. Usually we create a new Reduction, assign it to the Data property
               'of Head and push it on the stack. However, in this case, the Data property of the
               'Head will be assigned the Data property of the reduced token (i.e. the only one
               'on the stack).
               'In this case, to save code, the value popped of the stack is changed into the head.
               
               Set Head = Stack.Pop()
               Set Head.ParentSymbol = CurrentRule.RuleNonterminal
               
               Result = ParseResultReduceEliminated
           Else                                           'Build a Reduction
               pHaveReduction = True
               Set NewReduction = New Reduction
               With NewReduction
                   Set .ParentRule = CurrentRule
                   .TokenCount = CurrentRule.SymbolCount
                   For n = .TokenCount - 1 To 0 Step -1
                       Set .Tokens(n) = Stack.Pop()
                   Next
               End With
                    
               Set Head = New Token
               Set Head.Data = NewReduction
               Set Head.ParentSymbol = CurrentRule.RuleNonterminal
               
               Result = ParseResultReduceNormal
           End If
                    
           '========== Goto
           Index = Stack.Top().State
                
           '========= If n is -1 here, then we have an Internal Table Error!!!!
           n = pActionTable.Member(Index).ActionIndexForSymbol(CurrentRule.RuleNonterminal.TableIndex)
           If n <> -1 Then
               CurrentLALR = pActionTable.Member(Index).Item(n).Value

               Head.State = CurrentLALR
               Stack.Push Head
           Else
               Result = ParseResultInternalError
           End If
       End Select
   
   Else
       '=== Syntax Error! Fill Expected Tokens
       pTokens.Clear
       For n = 0 To pActionTable.Member(CurrentLALR).Count - 1
           '01/26/2002: Fixed bug. EOF was not being added to the expected tokens
           Select Case pActionTable.Member(CurrentLALR).Item(n).Symbol.Kind
           Case SymbolTypeTerminal, SymbolTypeEnd
               Set Head = New Token
               Head.Data = ""
               Set Head.ParentSymbol = pActionTable.Member(CurrentLALR).Item(n).Symbol
               pTokens.Push Head
           End Select
       Next
       'If pTokens.Count = 0 Then Stop
       Result = ParseResultSyntaxError
   End If
      
   ParseToken = Result     'Very important
      
End Function

Public Function OpenFile(FileName As String) As Boolean
   Dim Success As Boolean
   
   '=== 11/21/01: Found a bug after a user complained that they could not open a file. The
   '=== Reset procedure was called AFTER the load. Naturally, it did not work.
   Reset
   Success = pSource.OpenFile(FileName, "r")
   PrepareToParse
   OpenFile = Success

End Function

Public Sub Reset()
   Dim n As Integer
   
   '================= Setup global varibles
   For n = 0 To pSymbolTable.Count - 1
      Select Case pSymbolTable.Member(n).Kind
      Case SymbolTypeError
         Set kErrorSymbol = pSymbolTable.Member(n)
      Case SymbolTypeEnd
         Set kEndSymbol = pSymbolTable.Member(n)
      End Select
   Next
   
   pCompareMode = IIf(pVariables.Value("Case Sensitive") = "True", vbBinaryCompare, vbTextCompare)
      
   CurrentLALR = InitialLALRState
   pLineNumber = 1
   pSource.CloseFile
   pCommentLevel = 0
   pHaveReduction = False
   
   pTokens.Clear
   pInputTokens.Clear
   Stack.Clear
  ' Variables.ClearValues
   
End Sub

Private Function RetrieveToken(Source As LookaheadStream) As Token      'Symbol Index
   'This function implements the DFA algorithm and returns a token to the LALR state
   'machine

   Dim ch As String, n As Integer, Found As Boolean, Done As Boolean, Target As Integer
   Dim CharSetIndex As Integer, CurrentDFA As Integer, CurrentPosition As Long
   Dim LastAcceptState As Integer, LastAcceptPosition As Integer
   Dim Result As New Token
   
   Done = False
   CurrentDFA = InitialDFAState           'The first state is almost always #1.
   CurrentPosition = 1                    'Next byte in the input LookaheadStream
   LastAcceptState = -1                   'We have not yet accepted a character string
   LastAcceptPosition = -1
   
   If Not Source.Done Then
      Do Until Done
         '======= This code searches all the branches of the current DFA state for the next
         '======= character in the input LookaheadStream. If found the target state is returned.
         '======= The InStr() function searches the string pCharacterSetTable.Member(CharSetIndex)
         '======= starting at position 1 for ch.  The pCompareMode variable determines whether
         '======= the search is case sensitive.
         ch = Source.NextCharacter(CurrentPosition, False)
         If ch = "" Then         'End reached, do not match
            Found = False
         Else
            n = 0
            Found = False
            Do While n < pDFA.Member(CurrentDFA).EdgeCount And Not Found
               CharSetIndex = pDFA.Member(CurrentDFA).Edge(n).Characters
               If InStr(1, pCharacterSetTable.Member(CharSetIndex), ch, pCompareMode) <> 0 Then
                  Found = True
                  Target = pDFA.Member(CurrentDFA).Edge(n).TargetIndex
               End If
               n = n + 1
            Loop
         End If
         
         '======= This block-if statement checks whether an edge was found from the current state.
         '======= If so, the state and current position advance. Otherwise it is time to exit the main loop
         '======= and report the token found (if there was it fact one). If the LastAcceptState is -1,
         '======= then we never found a match and the Error Token is created. Otherwise, a new token
         '======= is created using the Symbol in the Accept State and all the characters that
         '======= comprise it.
         
         If Found Then
             '======= This code checks whether the target state accepts a token. If so, it sets the
             '======= appropiate variables so when the algorithm in done, it can return the proper
             '======= token and number of characters.
             If pDFA.Member(Target).AcceptSymbol <> -1 Then
                LastAcceptState = Target
                LastAcceptPosition = CurrentPosition
             End If
                  
             CurrentDFA = Target
             CurrentPosition = CurrentPosition + 1
         Else                                           'No edge found
             Done = True
             If LastAcceptState = -1 Then                'Tokenizer cannot recognize symbol
                Set Result.ParentSymbol = kErrorSymbol
                Result.Data = Source.Read(1)
             Else                                                'Create Token, read characters
                Set Result.ParentSymbol = pSymbolTable.Member(pDFA.Member(LastAcceptState).AcceptSymbol)
                Result.Data = Source.Read(LastAcceptPosition)    'The data contains the total number of accept characters
             End If
         End If
         DoEvents
      Loop
   Else
      Result.Data = ""                                  'End of file reached, create End Token
      Set Result.ParentSymbol = kEndSymbol
   End If
   
   '======= Count Carriage Returns and increment the Line Number. This is done for the
   '======= Developer and is not necessary for the DFA algorithm
   For n = 1 To Len(Result.Data)
     If Mid(Result.Data, n, 1) = vbCr Then
         pLineNumber = pLineNumber + 1
     End If
   Next
   'If pLineNumber Mod 1000 = 0 Then Stop
   Set RetrieveToken = Result

End Function






Private Sub Class_Initialize()

    Reset
    pTablesLoaded = False
    
    '======= Default Properties
    pTrimReductions = True
End Sub


Private Sub Class_Terminate()
    '== 12/20/2001: Added all the 'set X = nothing statements'
    Set pSymbolTable = Nothing
    Set pDFA = Nothing
    Set pCharacterSetTable = Nothing
    Set pRuleTable = Nothing
    Set pVariables = Nothing
    Set pActionTable = Nothing
    
    Set kErrorSymbol = Nothing
    Set kEndSymbol = Nothing
    
    Set Stack = Nothing
    Set pTokens = Nothing
    
    Set pInputTokens = Nothing
    Set pSource = Nothing
End Sub


