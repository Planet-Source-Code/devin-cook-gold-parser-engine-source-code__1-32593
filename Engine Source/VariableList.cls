VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "VariableList"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'================================================================================
' Class Name:
'      VariableList
'
' Instancing:
'      Private; Internal  (VB Setting: 1 - Private)
'
' Purpose:
'      This is a very simple class that stores a list of "variables". The GOLDParser
'      class uses a this class to store the parameter fields.
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

Private Type VariableType
   Name    As String
   Value   As String
End Type

Private MemberList() As VariableType
Private MemberCount As Integer

Public Function Add(Name As String, Optional Value As String = "") As Boolean

   Dim n As Integer, Found As Boolean
   
   n = 0
   Found = False
   Do While n < MemberCount And Not Found
     Found = MemberList(n).Name = Name
     n = n + 1
   Loop
   
   If Not Found Then
      MemberCount = MemberCount + 1
      ReDim Preserve MemberList(0 To MemberCount - 1)     'Change the size of the array
      MemberList(MemberCount - 1).Name = Name
      MemberList(MemberCount - 1).Value = Value
   End If
   
   Add = Not Found
End Function

Public Sub ClearValues()
   
   Dim n As Integer
   
   For n = 0 To MemberCount - 1
      MemberList(n).Value = ""
   Next

End Sub

Public Function Count() As Integer

   Count = MemberCount

End Function

Public Function Name(Index As Integer) As String

   If Index >= 0 And Index < MemberCount Then
      Name = MemberList(Index).Name
   End If

End Function




Public Property Let Value(Name As Variant, Value As String)

   Dim Index As Integer
   
   '==== Find the index of the variable
   If VarType(Name) = vbString Then
      Index = VariableIndex(CStr(Name))
   Else
      Index = CInt(Name)
   End If
   
   '==== Store it
   If Index >= 0 And Index < MemberCount Then
      MemberList(Index).Value = Value
   End If

End Property
Public Property Get Value(Name As Variant) As String

   Dim Index As Integer
   
   '==== Find the index of the variable
   If VarType(Name) = vbString Then
      Index = VariableIndex(CStr(Name))
   Else
      Index = CInt(Name)
   End If
   
   '==== Return it
   If Index >= 0 And Index < MemberCount Then
      Value = MemberList(Index).Value
   End If

End Property
Public Function VariableIndex(Name As String) As Integer

   Dim Index As Integer, n As Integer, Found As Boolean
   
   Index = -1
   n = 0
   Do While n < MemberCount And Index = -1
      If MemberList(n).Name = Name Then
         Index = n
      End If
      n = n + 1
   Loop
   
   VariableIndex = Index

End Function


