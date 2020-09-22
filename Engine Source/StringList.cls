VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "StringList"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'================================================================================
' Class Name:
'      StringList
'
' Instancing:
'      Private; Internal  (VB Setting: 1 - Private)
'
' Purpose:
'      Contains a list of strings
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

Private MemberList() As String
Private MemberCount As Long

Public Sub Clear()

   Erase MemberList
   MemberCount = 0

End Sub

Public Function Count() As Long

   Count = MemberCount

End Function



Property Get Member(ByVal Index As Long) As String

   If Index >= 0 And Index < MemberCount Then
      Member = MemberList(Index)
   End If

End Property

Property Let Member(ByVal Index As Long, Text As String)
   
   If Index >= 0 And Index < MemberCount Then
      MemberList(Index) = Text
   End If

End Property

Public Sub Add(Text As String)

   MemberCount = MemberCount + 1
   ReDim Preserve MemberList(0 To MemberCount - 1)     'Change the size of the array
   MemberList(MemberCount - 1) = Text

End Sub


Public Sub ReDimension(ByVal NewCount As Long)

   MemberCount = NewCount
   ReDim Preserve MemberList(0 To MemberCount - 1)     'Change the size of the array

End Sub


