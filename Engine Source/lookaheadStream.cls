VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "LookaheadStream"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'================================================================================
' Class Name:
'      LookaheardStream (Basic version)
'
' Instancing:
'      Private; Internal  (VB Setting: 1 - Private)
'
' Purpose:
'       This class is used to create a very basic version of the stream object that
'       exists in the C++ programming language. Using streams, the programmer can read
'       data from any number of sources while masking this from the code using the
'       stream. Visual Basic .NET will add this functionality.
'
'       Given the limited use of this class, this verson only has the ability to read
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


Public Enum StreamTransferConstants
   StreamTransferBinary = 1
   StreamTransferText = 2
End Enum

Public Enum StreamStringTypeConstants
   StreamStringTypeASCII = 1
   StreamStringTypeUnicode = 2
End Enum

Private Enum StreamTargetConstants
   StreamTargetString = 1
   StreamTargetFile = 2
   'StreamTargetSocket
End Enum

'========= File Streaming
Private pStreamFile As String          'FileName
Private pFileNumber As Integer
Private pFileOpen As Boolean
Private StreamTransfer As StreamTransferConstants

'========= The main data type and control
Private Const kMaxBufferSize = 1024
Private Buffer As String             'Up to 2 billion chars
Private Position As Long             'Current position in the buffer

Private StreamTarget As StreamTargetConstants
Private StreamCanRead As Boolean

'========= Public data types
Public StringType  As StreamStringTypeConstants
Private Sub CloseStream()
   If StreamTarget And pFileOpen Then
       Close pFileNumber
       pFileOpen = False
   End If
End Sub

Public Function FileOpen() As Boolean
   FileOpen = pFileOpen

End Function


Private Function ReadInt16() As Integer
   'This function reads bytes in Little Endian format.
   
   Dim str As String, n As Integer, Result As Long
   str = ReadFromBuffer(2)
   
   If str <> "" Then
       Result = Asc(Mid(str, 1, 1)) + CLng(Asc(Mid(str, 2, 1))) * 256
   
       If Result > 32767 Then      'Negate
           Result = -(65535 - Result + 1)        '2s compliment
       End If
    
       ReadInt16 = Result
   Else
       ReadInt16 = 0
   End If

End Function

Public Function ReadVariable(DataType As VbVarType) As Variant

    'This function reads the appropiate number of characters from the buffer
    'and reconstructs the data type. It is then returned.
   
    Dim Variable As Variant, Length As Long, n As Long, CharNumber As Integer
   
    If StreamTransfer = StreamTransferBinary Then
       Select Case DataType
       Case vbSingle, vbDouble, vbLong
           MsgBox "Floating point variables and long integers are not supported in this version."
       Case vbInteger
           Variable = ReadInt16()
       Case vbByte
           Variable = Asc(ReadFromBuffer(1))
       Case vbString
          Select Case StringType
          Case StreamStringTypeASCII
              Variable = ReadUntil(Chr(0))
                  
          Case StreamStringTypeUnicode
              CharNumber = ReadInt16()
              Variable = ""                     'First char is assigned in first loop
              Do Until CharNumber = 0
                  Variable = Variable & ChrW(CharNumber)
                  CharNumber = ReadInt16()
              Loop
          End Select
      
      End Select
   Else
      Variable = ReadUntil(Chr(0))
   End If
   
   ReadVariable = Variable

End Function












Private Function BufferFill(Optional ByVal RequiredSize As Long = kMaxBufferSize) As Long
   'This procedure is activated when the Stream is being read from a file
   'If the RequiredSize is less than what is available, the following happens:
   'data is read to either the total amount of needed is in the buffer
   'The number of bytes read corresponds is the max of the RequiredSize
   'and kMaxBuffer variables
   'Returns: The total number of bytes available
   
   'Modified 12/28/2001: A user reported a bug where the last character of a Stream is not read
   'I added the '+ 1' to 'FileLeft = LOF(pFileNumber) - Seek(pFileNumber) + 1'. The error handler
   'was also added
   
   On Error GoTo Problem
   
   Dim n As Long, FileLeft As Long
   
   '========== Move data
   If BufferLeft <= 0 Then
      Buffer = ""
      Position = 1
   Else
      Buffer = Mid(Buffer, Position)      'Rest of Buffer is beginning
      Position = 1
   End If
   
   '=== The total bytes left
   If EOF(pFileNumber) Then
      FileLeft = 0
   Else
      FileLeft = LOF(pFileNumber) - Seek(pFileNumber) + 1
   End If
   
   'n is the largest required block size
   n = IIf(RequiredSize > kMaxBufferSize, RequiredSize, kMaxBufferSize) - Len(Buffer)
   
   If FileLeft <= 0 Then                      'Close
       CloseFile
   ElseIf n > FileLeft Then                   'This read will finish the rest of the file
       n = FileLeft                            'The number of bytes to read
       Buffer = Buffer & Input(n, pFileNumber)
       CloseFile
   Else
       Buffer = Buffer & Input(n, pFileNumber)
   End If
      
   BufferFill = IIf(n < RequiredSize, n, RequiredSize)

   Exit Function

Problem:
   Buffer = ""
   BufferFill = 0
   CloseFile            'Close the input on a crash

End Function
Private Function BufferLeft() As Long

   BufferLeft = Len(Buffer) - Position + 1

End Function

Public Sub CloseFile()

   If pFileOpen Then
       CloseStream
   End If

End Sub

Public Function Done() As Boolean

   Select Case StreamTarget
   Case StreamTargetString
       Done = BufferLeft() <= 0
   Case StreamTargetFile
       Done = Not pFileOpen And BufferLeft() <= 0
   End Select

End Function


Public Function NextCharacter(Optional ByVal Length As Integer = 1, Optional ReturnAllText As Boolean = False) As String

   If StreamCanRead Then
      NextCharacter = ReadFromBuffer(Length, False, ReturnAllText)
   Else
      NextCharacter = ""
   End If

End Function


Public Function OpenFile(FileName As String, Optional BinaryMode As Boolean = False) As Boolean

   On Error Resume Next
   Dim Success As Boolean, n As Long
   
   If pFileOpen Then
      Close pFileNumber
   End If
      
   StreamTransfer = IIf(BinaryMode, StreamTransferBinary, StreamTransferText)
   
   Success = True             'Unless determined otherwise
   StreamCanRead = True
   pFileNumber = FreeFile
   
   If FileExists(FileName) Then
       Open FileName For Binary Access Read As pFileNumber
       
       '========================= Check header or react to error
       If Err.Number = 0 Then
           pFileOpen = True
           StreamTarget = StreamTargetFile
       Else
           Err.Clear
           pFileOpen = False
           Success = False
       End If
   Else
       Success = False
   End If
    
   OpenFile = Success
End Function

Public Function FileExists(FullPath As String) As Boolean
   
    Dim CurrentFile As String, Found As Boolean
    Dim FileName As String, Folder As String
   
    '=================== Dissect the path and get the FileName and folder
    Dim n As Integer, Position As String
    
    n = Len(FullPath)
    Position = 0
    
    Do While n >= 1 And Position = 0
        If Mid(FullPath, n, 1) = "\" Then
            Position = n
        End If
        n = n - 1
    Loop
       
    If Position >= 1 And Position < Len(FullPath) Then   'We have a folder and file
        FileName = Mid(FullPath, Position + 1)
        Folder = Left(FullPath, Position)
    End If

    '=================== Search the folder for the file
    Found = False
    If FileName <> "" And Folder <> "" Then     'Look for the file
        CurrentFile = Dir(Folder & "*.*")
        
        Do While CurrentFile <> "" And Not Found
            If UCase(CurrentFile) = UCase(FileName) Then
                Found = True
            End If
            CurrentFile = Dir()     'Get next
        Loop
    End If
    
    FileExists = Found
   
End Function
Public Function GetFilePath(FullPath As String) As String
    'This procedure removes the extension from a filename
       
    Dim n As Integer, Position As String
    
    n = Len(FullPath)
    Position = 0
    
    Do While n >= 1 And Position = 0
       If Mid(FullPath, n, 1) = "\" Then
          Position = n
       End If
       n = n - 1
    Loop

    If Position <= 1 Then                                  'No extension
        GetFilePath = ""
    Else
        GetFilePath = Left(FullPath, Position)
    End If
        
End Function
Public Function GetFileName(FullPath As String) As String
    'This procedure removes the extension from a filename
       
    Dim n As Integer, Position As String
    
    n = Len(FullPath)
    Position = 0
    
    Do While n >= 1 And Position = 0
       If Mid(FullPath, n, 1) = "\" Then
          Position = n
       End If
       n = n - 1
    Loop

    If Position = 0 Then                                  'No extension
        GetFileName = FullPath
    ElseIf Position = Len(FullPath) Then
        GetFileName = ""
    Else
        GetFileName = Mid(FullPath, Position + 1)
    End If
        
End Function


Public Function Read(Optional Length As Integer = 1) As String

   'This function reads the appropiate amount of characters from the
   'buffer and constucts the requested datatype
   
   If StreamCanRead Then
      Read = ReadFromBuffer(Length)
   Else
      Read = ""
   End If

End Function
Public Function ReadUntil(ByVal EndChar As String) As String

   Dim EndReached As Boolean, TextSegment As String, ch As String
   
   If StreamCanRead Then
      If EndChar = "" Then EndChar = Left(vbNewLine, 1)
      If Len(EndChar) > 1 Then EndChar = Left(EndChar, 1)
   
      EndReached = False
      Do Until EndReached Or Done()
         ch = Read()
         If StrComp(ch, EndChar, vbBinaryCompare) <> 0 Then
            TextSegment = TextSegment & ch
         Else
            EndReached = True
         End If
      Loop
      ReadUntil = TextSegment
   
   Else
      ReadUntil = ""
   End If

End Function




Private Function ReadFromBuffer(Optional ByVal Size As Integer = 1, Optional DiscardReadText As Boolean = True, Optional ReturnAllText As Boolean = True) As String

   'This function takes data from the buffer and creates a string of the
   'appropiate size. This can be destructive (advanced position) or not
      
   Dim Available As Long
     
   If BufferLeft() < Size And pFileOpen Then
      Available = BufferFill(Size)
   Else
      Available = Size
   End If
     
   If ReturnAllText Then
      ReadFromBuffer = Mid(Buffer, Position, Available)    'Get data
   ElseIf Available >= Size Then
      ReadFromBuffer = Mid(Buffer, Position + Size - 1, 1)
   Else
      ReadFromBuffer = ""
   End If
   
   If DiscardReadText Then
      Position = Position + Available
   End If

End Function


Property Get Text() As String
Attribute Text.VB_UserMemId = 0
   
   If StreamTarget = StreamTargetString And Position <= Len(Buffer) Then     'Fill the buffer
      Text = Mid(Buffer, Position)
   Else
      Text = ""
   End If

End Property

Property Let Text(NewString As String)

   If StreamTarget = StreamTargetString Then
      Position = 1
      Buffer = NewString
   End If

End Property

Private Sub Class_Initialize()
    Buffer = ""
    Position = 1
    StreamTransfer = StreamTransferText
    StreamCanRead = True
    StreamTarget = StreamTargetString
    StringType = StreamStringTypeASCII
End Sub
Public Function ReadLine() As String

    Dim EndReached As Boolean, Text As String, ch As String
   
    If StreamCanRead Then
        EndReached = False
        Do Until EndReached Or Done()
            ch = ReadFromBuffer(1)
            If ch = Chr(10) Or ch = Chr(13) Then         'End char
                ch = ReadFromBuffer(1, False)
                If ch = Chr(10) Or ch = Chr(13) Then     'Discard second of line-feed, carriage return pair
                    ReadFromBuffer 1
                End If
                EndReached = True
            Else
                Text = Text & ch
            End If
        Loop
        ReadLine = Text
    Else
        ReadLine = ""
    End If

End Function

Private Sub Class_Terminate()

If pFileOpen Then
   CloseFile
End If

End Sub


