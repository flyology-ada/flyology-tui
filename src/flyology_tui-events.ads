with Ada.Real_Time;
with Ada.Strings.Wide_Wide_Unbounded;

package Flyology_TUI.Events is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Modifiers is record
      Shift   : Boolean := False;
      Control : Boolean := False;
      Alt     : Boolean := False;
      Super   : Boolean := False;
   end record;

   type Key_Kind is
     (Text_Key,
      Escape_Key,
      Enter_Key,
      Tab_Key,
      Backspace_Key,
      Insert_Key,
      Delete_Key,
      Home_Key,
      End_Key,
      Page_Up_Key,
      Page_Down_Key,
      Arrow_Up_Key,
      Arrow_Down_Key,
      Arrow_Left_Key,
      Arrow_Right_Key,
      Function_Key);

   type Key_Event (Kind : Key_Kind := Text_Key) is record
      Modified : Modifiers;
      Repeated : Boolean := False;
      case Kind is
         when Text_Key =>
            Value : Text.Unbounded_Wide_Wide_String;
         when Function_Key =>
            Number : Positive := 1;
         when others =>
            null;
      end case;
   end record;

   type Mouse_Button is
     (No_Button,
      Left_Button,
      Middle_Button,
      Right_Button,
      Auxiliary_Button_1,
      Auxiliary_Button_2);

   type Mouse_Action is
     (Mouse_Click,
      Mouse_Release,
      Mouse_Move,
      Mouse_Drag,
      Mouse_Wheel);

   type Mouse_Event is record
      X          : Natural := 0;
      Y          : Natural := 0;
      Button     : Mouse_Button := No_Button;
      Action     : Mouse_Action := Mouse_Move;
      Modified   : Modifiers;
      Wheel_X    : Integer := 0;
      Wheel_Y    : Integer := 0;
   end record;

   type Terminal_Event_Kind is
     (Key_Press,
      Key_Release,
      Paste,
      Resize,
      Mouse_Input,
      Focus_Gained,
      Focus_Lost,
      Tick,
      Interrupt);

   type Terminal_Event
     (Kind : Terminal_Event_Kind := Interrupt)
   is record
      case Kind is
         when Key_Press | Key_Release =>
            Key : Key_Event;
         when Paste =>
            Pasted_Text : Text.Unbounded_Wide_Wide_String;
         when Resize =>
            Width  : Natural := 0;
            Height : Natural := 0;
         when Mouse_Input =>
            Mouse : Mouse_Event;
         when Tick =>
            At_Time : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
         when Focus_Gained | Focus_Lost | Interrupt =>
            null;
      end case;
   end record;

   function Pressed (Key : Key_Event) return Terminal_Event;
   function Released (Key : Key_Event) return Terminal_Event;
   function Resized (Width, Height : Natural) return Terminal_Event;
end Flyology_TUI.Events;
