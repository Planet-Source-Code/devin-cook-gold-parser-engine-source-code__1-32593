VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "FAState"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'================================================================================
' Class Name:
'      FAState
'
' Instancing:
'      Private; Internal  (VB Setting: 1 - Private)
'
' Purpose:
'      Represents a state in the Deterministic Finite Automata which is used by
'      the tokenizer.
'
' Author(s):
'      Devin Cook
'      GOLDParser@DevinCook.com
'
' Dependacies:
'      FAEdge
'
'================================================================================

Option Explicit

Private Edges As New ObjectList
Public AcceptSymbol As Integer




Public Sub AddEdge(ByVal Characters As String, ByVal Target As Integer)

   Dim Edge As FAEdge, n As Integer, Index As Integer
   
   If Characters = "" Then         'Lambda edge - always add
      Set Edge = New FAEdge
      Edge.Characters = ""
      Edge.TargetIndex = Target
      Edges.Add Edge
   Else
      Index = -1
      n = 0
      Do While n < Edges.Count And Index = -1
         If Edges.Member(n).TargetIndex = Target Then
             Index = n
         End If
         n = n + 1
      Loop
   
      If Index = -1 Then
         Set Edge = New FAEdge
         Edge.Characters = Characters
         Edge.TargetIndex = Target
         Edges.Add Edge
      Else
         Edges.Member(Index).Characters = Edges.Member(Index).Characters & Characters
      End If
   End If

End Sub
Public Function Edge(Index As Integer) As FAEdge

   If Index >= 0 And Index < Edges.Count Then
       Set Edge = Edges.Member(Index)
   End If

End Function

Public Function EdgeCount() As Integer

   EdgeCount = Edges.Count

End Function


Private Sub Class_Initialize()

'VariableLength = False

End Sub


