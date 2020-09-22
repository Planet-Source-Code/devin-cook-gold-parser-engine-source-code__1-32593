VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "SimpleDataBase"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'================================================================================
' Class Name:
'      SimpleDatabase (Basic version)
'
' Instancing:
'      Private; Internal  (VB Setting: 1 - Private)
'
' Purpose:
'      This class is used to read information stored in the very simple file
'      structure used by the Compiled Grammar Table file.
'
'      Record Structure
'         |1 byte         | 2 byte      | Variable size
'         |Character 'M'  | Entry Count | Entries (0 to 32k)
'
'      For more information, please consult http://www.DevinCook.com/GOLDParser/doc/cgt/
'
' Author(s):
'      Devin Cook
'      GOLDParser@DevinCook.com
'
' Dependacies:
'      (None)
'
'================================================================================

Option Explicit
Option Compare Text

Private EntryList()       As Variant
Private EntryListCount    As Integer
Private EntryReadPosition As Integer

Private Const RecordContentMulti = 77  'M

Private Enum EntryContentConstants
    EntryContentEmpty = 69        'E
    EntryContentInteger = 73      'I - Signed, 2 byte
    EntryContentString = 83       'S - Unicode format
    EntryContentBoolean = 66      'B - 1 Byte, Value is 0 or 1
    EntryContentByte = 98         'b
End Enum

Private pHeader As String
Private iostream As New LookaheadStream


Public Function RetrieveDone() As Boolean

   RetrieveDone = Not (EntryReadPosition < EntryListCount)

End Function


Public Function RetrieveNext() As Variant

   If Not RetrieveDone() Then
      RetrieveNext = EntryList(EntryReadPosition)
      EntryReadPosition = EntryReadPosition + 1
   Else
      RetrieveNext = Empty
   End If

End Function

Public Sub Store(Value As Variant)
   EntryListCount = EntryListCount + 1
   
   ReDim Preserve EntryList(0 To EntryListCount - 1)     'Change the size of the array
   EntryList(EntryListCount - 1) = Value
End Sub

Public Sub Clear()
   
   EntryListCount = 0
   EntryReadPosition = 0
   Erase EntryList

End Sub

Public Sub CloseFile()

   If iostream.FileOpen Then
      iostream.CloseFile
   End If

End Sub

Public Function EntryCount() As Integer

   EntryCount = EntryListCount

End Function

Public Function Done() As Boolean

    Done = iostream.Done

'    If iostream.FileOpen And pFileMode = "R" Then
'       Done = iostream.Done ' Loc(FileNumber) + 1 >= LOF(FileNumber)
'      ' If LOF(FileNumber) - Loc(FileNumber) < 10 Then Stop
'       'Done = EOF(FileNumber)
'    Else
'       Done = True
'    End If

End Function


Public Function Entry(ByVal Index As Integer) As Variant

   If Index >= 0 And Index < EntryListCount Then
      Entry = EntryList(Index)
   Else
      Entry = Null
   End If

End Function

Property Get FileType() As String

   FileType = pHeader

End Property

Property Let FileType(Name As String)

   pHeader = Name

End Property


Private Function HasValidHeader() As Boolean

   'This reads characters from the source file until a null
   'character is encountered. It then tests to see if it matches
   'the FileType
   
   Dim FileHeader As String ', Char As Integer, Done As Boolean
   
   FileHeader = iostream.ReadVariable(vbString)
 
   HasValidHeader = (FileHeader = pHeader)

End Function

Public Function OpenFile(FileName As String) As Boolean
   Dim Success As Boolean
   On Error Resume Next
   
   If iostream.FileOpen Then
      iostream.CloseFile
   End If
   
   iostream.OpenFile FileName, True
      
   '========================= Check header or react to error
   If iostream.FileOpen Then
      Success = HasValidHeader
   Else
      Success = False
   End If
   
   OpenFile = Success
End Function


Private Function ReadEntry() As Variant
    Dim Id As Byte, Value As Variant, Result As Variant    ', b As Byte
    
    Id = iostream.ReadVariable(vbByte)
      
    Select Case Id
    Case EntryContentEmpty
        Result = Empty
    Case EntryContentBoolean
        Value = iostream.ReadVariable(vbByte)
        Result = IIf(Value = 1, True, False)
    Case EntryContentInteger
        Result = iostream.ReadVariable(vbInteger)
    Case EntryContentString
        Result = iostream.ReadVariable(vbString)
    Case EntryContentByte
        Result = iostream.ReadVariable(vbByte)
    Case Else
       MsgBox "Error on CGT read"
       Result = Empty
    End Select
   
    ReadEntry = Result
End Function



Public Function GetNextRecord() As Boolean

   Dim n As Integer, Count As Integer, Id As Byte, Success As Boolean
   Dim Value As Variant
   
   If (Not iostream.Done) Then
      Id = iostream.ReadVariable(vbByte)
      
      Select Case Id
      Case RecordContentMulti
          Clear
          Count = iostream.ReadVariable(vbInteger)
          For n = 1 To Count
             Store ReadEntry()
          Next
          EntryReadPosition = 0
          Success = True
   
      Case Else
          Success = False
      End Select
        
   Else
      Success = False
   End If
   
   GetNextRecord = Success

End Function


Private Sub Class_Initialize()

    pHeader = "Simple DataBase"
    EntryReadPosition = 1
    
    With iostream
       .StringType = StreamStringTypeUnicode
    End With

End Sub

Private Sub Class_Terminate()

CloseFile

End Sub


