with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Strings.Wide_Wide_Unbounded;

package body Flyology_TUI.Input is
   use type Flyology_TUI.Events.Mouse_Button;
   package Bytes renames Ada.Strings.Unbounded;
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   ESC : constant Character := Ada.Characters.Latin_1.ESC;
   Paste_Start : constant String := ESC & "[200~";
   Paste_End   : constant String := ESC & "[201~";

   procedure Push
     (Item  : in out Parser;
      Event : Flyology_TUI.Events.Terminal_Event) is
   begin
      Item.Events.Append (Event);
   end Push;

   procedure Consume (Item : in out Parser; Count : Natural) is
      Value : constant String := Bytes.To_String (Item.Buffer);
   begin
      if Count >= Value'Length then
         Item.Buffer := Bytes.Null_Unbounded_String;
      else
         Item.Buffer := Bytes.To_Unbounded_String
           (Value (Value'First + Count .. Value'Last));
      end if;
   end Consume;

   function UTF_8_Length (First : Character) return Natural is
      Code : constant Natural := Character'Pos (First);
   begin
      if Code < 16#80# then
         return 1;
      elsif Code in 16#C2# .. 16#DF# then
         return 2;
      elsif Code in 16#E0# .. 16#EF# then
         return 3;
      elsif Code in 16#F0# .. 16#F4# then
         return 4;
      else
         return 0;
      end if;
   end UTF_8_Length;

   function Decode (Value : String) return Wide_Wide_String is
      Encoded : constant Ada.Strings.UTF_Encoding.UTF_8_String :=
        Ada.Strings.UTF_Encoding.UTF_8_String (Value);
   begin
      return
        Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (Encoded);
   end Decode;

   function Text_Key
     (Value    : Wide_Wide_String;
      Modified : Flyology_TUI.Events.Modifiers := (others => False))
      return Flyology_TUI.Events.Terminal_Event
   is
      Key : constant Flyology_TUI.Events.Key_Event :=
        (Kind     => Flyology_TUI.Events.Text_Key,
         Modified => Modified,
         Repeated => False,
         Value    => Text.To_Unbounded_Wide_Wide_String (Value));
   begin
      return Flyology_TUI.Events.Pressed (Key);
   end Text_Key;

   function Special_Key
     (Kind     : Flyology_TUI.Events.Key_Kind;
      Modified : Flyology_TUI.Events.Modifiers := (others => False))
      return Flyology_TUI.Events.Terminal_Event
   is
      Key : Flyology_TUI.Events.Key_Event (Kind);
   begin
      Key.Modified := Modified;
      Key.Repeated := False;
      return Flyology_TUI.Events.Pressed (Key);
   end Special_Key;

   function Function_Key
     (Number   : Positive;
      Modified : Flyology_TUI.Events.Modifiers := (others => False))
      return Flyology_TUI.Events.Terminal_Event
   is
      Key : constant Flyology_TUI.Events.Key_Event :=
        (Kind     => Flyology_TUI.Events.Function_Key,
         Modified => Modified,
         Repeated => False,
         Number   => Number);
   begin
      return Flyology_TUI.Events.Pressed (Key);
   end Function_Key;

   function Modifiers_From (Parameter : Natural)
      return Flyology_TUI.Events.Modifiers
   is
      Bits : constant Natural :=
        (if Parameter = 0 then 0 else Parameter - 1);
   begin
      return
        (Shift   => Bits mod 2 = 1,
         Alt     => (Bits / 2) mod 2 = 1,
         Control => (Bits / 4) mod 2 = 1,
         Super   => (Bits / 8) mod 2 = 1);
   end Modifiers_From;

   function Number (Value : String; Valid : out Boolean) return Natural is
      Result : Natural := 0;
   begin
      Valid := Value'Length > 0;
      for Item of Value loop
         if Item not in '0' .. '9' then
            Valid := False;
            return 0;
         end if;
         if Result > (Natural'Last - (Character'Pos (Item) - 48)) / 10 then
            Valid := False;
            return 0;
         end if;
         Result := Result * 10 + Character'Pos (Item) - 48;
      end loop;
      return Result;
   end Number;

   procedure Parse_Mouse
     (Item  : in out Parser;
      Params : String;
      Final : Character)
   is
      First_Semicolon : constant Natural :=
        Ada.Strings.Fixed.Index (Params, ";");
      Second_Semicolon : Natural := 0;
      Good_B, Good_X, Good_Y : Boolean;
      Code, X, Y : Natural;
      Mouse : Flyology_TUI.Events.Mouse_Event;
   begin
      if Params'Length < 4 or else Params (Params'First) /= '<'
        or else First_Semicolon = 0
      then
         return;
      end if;
      Second_Semicolon := Ada.Strings.Fixed.Index
        (Params, ";", From => First_Semicolon + 1);
      if Second_Semicolon = 0 then
         return;
      end if;
      Code := Number
        (Params (Params'First + 1 .. First_Semicolon - 1), Good_B);
      X := Number
        (Params (First_Semicolon + 1 .. Second_Semicolon - 1), Good_X);
      Y := Number
        (Params (Second_Semicolon + 1 .. Params'Last), Good_Y);
      if not Good_B or else not Good_X or else not Good_Y then
         return;
      end if;

      Mouse.X := (if X = 0 then 0 else X - 1);
      Mouse.Y := (if Y = 0 then 0 else Y - 1);
      Mouse.Modified.Shift := (Code / 4) mod 2 = 1;
      Mouse.Modified.Alt := (Code / 8) mod 2 = 1;
      Mouse.Modified.Control := (Code / 16) mod 2 = 1;

      if (Code / 64) mod 2 = 1 then
         Mouse.Action := Flyology_TUI.Events.Mouse_Wheel;
         case Code mod 4 is
            when 0 => Mouse.Wheel_Y := 1;
            when 1 => Mouse.Wheel_Y := -1;
            when 2 => Mouse.Wheel_X := -1;
            when others => Mouse.Wheel_X := 1;
         end case;
      else
         case Code mod 4 is
            when 0 => Mouse.Button := Flyology_TUI.Events.Left_Button;
            when 1 => Mouse.Button := Flyology_TUI.Events.Middle_Button;
            when 2 => Mouse.Button := Flyology_TUI.Events.Right_Button;
            when others => Mouse.Button := Flyology_TUI.Events.No_Button;
         end case;
         if Final = 'm' then
            Mouse.Action := Flyology_TUI.Events.Mouse_Release;
         elsif (Code / 32) mod 2 = 1 then
            Mouse.Action :=
              (if Mouse.Button = Flyology_TUI.Events.No_Button
               then Flyology_TUI.Events.Mouse_Move
               else Flyology_TUI.Events.Mouse_Drag);
         else
            Mouse.Action := Flyology_TUI.Events.Mouse_Click;
         end if;
      end if;
      Push (Item, (Kind => Flyology_TUI.Events.Mouse_Input, Mouse => Mouse));
   end Parse_Mouse;

   procedure Parse_CSI
     (Item  : in out Parser;
      Params : String;
      Final : Character)
   is
      Separator : constant Natural :=
        Ada.Strings.Fixed.Index (Params, ";");
      Good : Boolean;
      Parameter : Natural := 1;
      Modified : Flyology_TUI.Events.Modifiers := (others => False);
      Primary : Natural := 0;
   begin
      if Params'Length > 0 and then Params (Params'First) = '<' then
         Parse_Mouse (Item, Params, Final);
         return;
      end if;

      if Separator /= 0 and then Separator < Params'Last then
         Parameter := Number
           (Params (Separator + 1 .. Params'Last), Good);
         if Good then
            Modified := Modifiers_From (Parameter);
         end if;
      end if;

      case Final is
         when 'A' =>
            Push
              (Item, Special_Key (Flyology_TUI.Events.Arrow_Up_Key, Modified));
         when 'B' =>
            Push
              (Item,
               Special_Key (Flyology_TUI.Events.Arrow_Down_Key, Modified));
         when 'C' =>
            Push
              (Item,
               Special_Key (Flyology_TUI.Events.Arrow_Right_Key, Modified));
         when 'D' =>
            Push
              (Item,
               Special_Key (Flyology_TUI.Events.Arrow_Left_Key, Modified));
         when 'H' =>
            Push (Item, Special_Key (Flyology_TUI.Events.Home_Key, Modified));
         when 'F' =>
            Push (Item, Special_Key (Flyology_TUI.Events.End_Key, Modified));
         when 'I' => Push (Item, (Kind => Flyology_TUI.Events.Focus_Gained));
         when 'O' => Push (Item, (Kind => Flyology_TUI.Events.Focus_Lost));
         when '~' =>
            declare
               Last : constant Natural :=
                 (if Separator = 0 then Params'Last else Separator - 1);
            begin
               Primary := Number
                 (Params (Params'First .. Last), Good);
               if Good then
                  case Primary is
                     when 2 =>
                        Push
                          (Item,
                           Special_Key
                             (Flyology_TUI.Events.Insert_Key, Modified));
                     when 3 =>
                        Push
                          (Item,
                           Special_Key
                             (Flyology_TUI.Events.Delete_Key, Modified));
                     when 5 =>
                        Push
                          (Item,
                           Special_Key
                             (Flyology_TUI.Events.Page_Up_Key, Modified));
                     when 6 =>
                        Push
                          (Item,
                           Special_Key
                             (Flyology_TUI.Events.Page_Down_Key, Modified));
                     when 11 .. 15 =>
                        Push (Item, Function_Key (Primary - 10, Modified));
                     when 17 .. 21 =>
                        Push (Item, Function_Key (Primary - 11, Modified));
                     when 23 .. 24 =>
                        Push (Item, Function_Key (Primary - 12, Modified));
                     when others => null;
                  end case;
               end if;
            end;
         when others => null;
      end case;
   end Parse_CSI;

   procedure Append_Paste (Item : in out Parser; Value : String) is
      Remaining : constant Natural :=
        Item.Max_Paste_Bytes - Natural'Min
          (Item.Max_Paste_Bytes, Bytes.Length (Item.Paste_Buffer));
   begin
      if Remaining > 0 then
         Bytes.Append
           (Item.Paste_Buffer,
            Value (Value'First .. Value'First + Natural'Min
              (Remaining, Value'Length) - 1));
      end if;
   end Append_Paste;

   function Process_Paste (Item : in out Parser) return Boolean is
      Value : constant String := Bytes.To_String (Item.Buffer);
      Marker : constant Natural := Ada.Strings.Fixed.Index (Value, Paste_End);
      Keep : constant Natural :=
        Natural'Min (Paste_End'Length - 1, Value'Length);
   begin
      if Marker /= 0 then
         if Marker > Value'First then
            Append_Paste (Item, Value (Value'First .. Marker - 1));
         end if;
         Consume (Item, Marker - Value'First + Paste_End'Length);
         declare
            Encoded : constant Ada.Strings.UTF_Encoding.UTF_8_String :=
              Ada.Strings.UTF_Encoding.UTF_8_String
                (Bytes.To_String (Item.Paste_Buffer));
            Value_Text : constant Wide_Wide_String :=
              Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (Encoded);
         begin
            Push
              (Item,
               (Kind        => Flyology_TUI.Events.Paste,
                Pasted_Text =>
                  Text.To_Unbounded_Wide_Wide_String (Value_Text)));
         exception
            when Ada.Strings.UTF_Encoding.Encoding_Error =>
               Push
                 (Item,
                  (Kind        => Flyology_TUI.Events.Paste,
                   Pasted_Text => Text.Null_Unbounded_Wide_Wide_String));
         end;
         Item.Paste_Buffer := Bytes.Null_Unbounded_String;
         Item.In_Paste := False;
         return True;
      elsif Value'Length > Keep then
         Append_Paste
           (Item, Value (Value'First .. Value'Last - Keep));
         Consume (Item, Value'Length - Keep);
      end if;
      return False;
   end Process_Paste;

   function Process_One (Item : in out Parser) return Boolean is
      Value : constant String := Bytes.To_String (Item.Buffer);
      First : Character;
   begin
      if Value'Length = 0 then
         return False;
      end if;
      if Item.In_Paste then
         return Process_Paste (Item);
      end if;

      if Value'Length >= Paste_Start'Length
        and then Value (Value'First .. Value'First + Paste_Start'Length - 1)
          = Paste_Start
      then
         Consume (Item, Paste_Start'Length);
         Item.In_Paste := True;
         return True;
      end if;

      First := Value (Value'First);
      if First = ESC then
         if Value'Length = 1 then
            return False;
         elsif Value (Value'First + 1) = '[' then
            for Pos in Value'First + 2 .. Value'Last loop
               if Value (Pos) in '@' .. '~' then
                  Parse_CSI
                    (Item,
                     Value (Value'First + 2 .. Pos - 1),
                     Value (Pos));
                  Consume (Item, Pos - Value'First + 1);
                  return True;
               end if;
            end loop;
            return False;
         elsif Value (Value'First + 1) = 'O' and then Value'Length >= 3 then
            case Value (Value'First + 2) is
               when 'P' => Push (Item, Function_Key (1));
               when 'Q' => Push (Item, Function_Key (2));
               when 'R' => Push (Item, Function_Key (3));
               when 'S' => Push (Item, Function_Key (4));
               when others => null;
            end case;
            Consume (Item, 3);
            return True;
         else
            declare
               Length : constant Natural :=
                 UTF_8_Length (Value (Value'First + 1));
               Alt : constant Flyology_TUI.Events.Modifiers :=
                 (Alt => True, others => False);
            begin
               if Length = 0 then
                  Push (Item, Special_Key (Flyology_TUI.Events.Escape_Key));
                  Consume (Item, 1);
               elsif Value'Length < Length + 1 then
                  return False;
               else
                  begin
                     Push
                       (Item,
                        Text_Key
                          (Decode
                             (Value
                                (Value'First + 1
                                 .. Value'First + Length)),
                           Alt));
                  exception
                     when Ada.Strings.UTF_Encoding.Encoding_Error =>
                        Push
                          (Item,
                           Text_Key
                             ((1 => Wide_Wide_Character'Val (16#FFFD#)), Alt));
                  end;
                  Consume (Item, Length + 1);
               end if;
               return True;
            end;
         end if;
      elsif First = Ada.Characters.Latin_1.CR
        or else First = Ada.Characters.Latin_1.LF
      then
         Push (Item, Special_Key (Flyology_TUI.Events.Enter_Key));
         Consume (Item, 1);
         return True;
      elsif First = Ada.Characters.Latin_1.HT then
         Push (Item, Special_Key (Flyology_TUI.Events.Tab_Key));
         Consume (Item, 1);
         return True;
      elsif First = Ada.Characters.Latin_1.BS
        or else Character'Pos (First) = 127
      then
         Push (Item, Special_Key (Flyology_TUI.Events.Backspace_Key));
         Consume (Item, 1);
         return True;
      elsif Character'Pos (First) in 1 .. 26 then
         declare
            Modified : constant Flyology_TUI.Events.Modifiers :=
              (Control => True, others => False);
            Letter : constant Wide_Wide_Character :=
              Wide_Wide_Character'Val
                (Wide_Wide_Character'Pos ('a') + Character'Pos (First) - 1);
         begin
            Push (Item, Text_Key ((1 => Letter), Modified));
            Consume (Item, 1);
            return True;
         end;
      else
         declare
            Length : constant Natural := UTF_8_Length (First);
         begin
            if Length = 0 then
               Push
                 (Item,
                  Text_Key ((1 => Wide_Wide_Character'Val (16#FFFD#))));
               Consume (Item, 1);
               return True;
            elsif Value'Length < Length then
               return False;
            end if;
            begin
               Push
                 (Item,
                  Text_Key
                    (Decode
                       (Value (Value'First .. Value'First + Length - 1))));
            exception
               when Ada.Strings.UTF_Encoding.Encoding_Error =>
                  Push
                    (Item,
                     Text_Key ((1 => Wide_Wide_Character'Val (16#FFFD#))));
            end;
            Consume (Item, Length);
            return True;
         end;
      end if;
   end Process_One;

   procedure Process (Item : in out Parser) is
   begin
      while Process_One (Item) loop
         null;
      end loop;
   end Process;

   procedure Initialize
     (Item            : in out Parser;
      Max_Paste_Bytes : Positive := 1_048_576) is
   begin
      Reset (Item);
      Item.Max_Paste_Bytes := Max_Paste_Bytes;
   end Initialize;

   procedure Feed (Item : in out Parser; Data : String) is
   begin
      Bytes.Append (Item.Buffer, Data);
      Process (Item);
   end Feed;

   procedure Flush_Escape (Item : in out Parser) is
      Value : constant String := Bytes.To_String (Item.Buffer);
   begin
      if Value'Length = 1 and then Value (Value'First) = ESC then
         Push (Item, Special_Key (Flyology_TUI.Events.Escape_Key));
         Consume (Item, 1);
      end if;
   end Flush_Escape;

   function Has_Event (Item : Parser) return Boolean is
     (not Item.Events.Is_Empty);

   procedure Next_Event
     (Item      : in out Parser;
      Event     : out Flyology_TUI.Events.Terminal_Event;
      Available : out Boolean)
   is
   begin
      Available := not Item.Events.Is_Empty;
      if Available then
         Event := Item.Events.First_Element;
         Item.Events.Delete_First;
      else
         Event := (Kind => Flyology_TUI.Events.Interrupt);
      end if;
   end Next_Event;

   procedure Reset (Item : in out Parser) is
   begin
      Item.Buffer := Bytes.Null_Unbounded_String;
      Item.Events.Clear;
      Item.In_Paste := False;
      Item.Paste_Buffer := Bytes.Null_Unbounded_String;
   end Reset;

end Flyology_TUI.Input;
