object Form1: TForm1
  Left = 294
  Top = 159
  Width = 921
  Height = 509
  Caption = 'Process List'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object ListView1: TListView
    Left = 0
    Top = 41
    Width = 913
    Height = 441
    Align = alClient
    Columns = <
      item
        Caption = 'Name'
        Width = 500
      end
      item
        Caption = 'PID'
        Width = 70
      end
      item
        Caption = 'Details'
        Width = 100
      end
      item
        Caption = 'User'
        Width = 200
      end>
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 913
    Height = 41
    Align = alTop
    TabOrder = 1
    object btnRefresh: TButton
      Left = 24
      Top = 8
      Width = 99
      Height = 25
      Caption = 'Refresh'
      TabOrder = 0
      OnClick = btnRefreshClick
    end
    object CheckBox1: TCheckBox
      Left = 144
      Top = 12
      Width = 97
      Height = 17
      Caption = 'Debug Prvilege'
      TabOrder = 1
      OnClick = CheckBox1Click
    end
  end
end
