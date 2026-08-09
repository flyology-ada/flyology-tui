pragma Restrictions (No_Tasking);

with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Chats;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Chat_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Message_Key is (One, Two, Three, Four, Five, Six, Seven);
   type Author_Key is (Alice, Ada_Bot, Runtime);

   function Author_Name (Author : Author_Key) return Wide_Wide_String is
     (case Author is
         when Alice   => "界 Alice",
         when Ada_Bot => "Ada bot",
         when Runtime => "runtime");

   package Chats is new Flyology_TUI.Components.Chats
     (Message_Id    => Message_Key,
      Author_Id     => Author_Key,
      Author_Label  => Author_Name,
      Capacity      => 6);

   use type Chats.Delivery_State;
   use type Chats.Message_Role;
   use type Flyology_TUI.Styles.Style;

   Empty_Messages : constant Chats.Message_Array (1 .. 0) :=
     (others =>
        (Id       => One,
         Author   => Alice,
         Role     => Chats.User,
         Delivery => Chats.Delivered,
         Sequence => 0));
   Empty_Measurements : constant Chats.Measurement_Array (1 .. 0) :=
     (others => (Id => One, Body_Height => 0, Action_Height => 0));
   Empty_Bodies : constant Chats.Body_Array (1 .. 0) :=
     (others =>
        (Id      => One,
         Content => Flyology_TUI.Surfaces.Create (0, 0),
         Actions => Flyology_TUI.Surfaces.Create (0, 0)));

   function Message
     (Id       : Message_Key;
      Author   : Author_Key;
      Role     : Chats.Message_Role;
      Delivery : Chats.Delivery_State := Chats.Delivered;
      Sequence : Natural := 0) return Chats.Message is
     (Id, Author, Role, Delivery, Sequence);

   procedure Assert (Condition : Boolean; Description : String) is
   begin
      if not Condition then
         raise Program_Error with Description;
      end if;
   end Assert;

   function Key (Kind : Flyology_TUI.Events.Key_Kind)
      return Flyology_TUI.Events.Terminal_Event
   is
      Value : Flyology_TUI.Events.Key_Event (Kind);
   begin
      Value.Modified := (others => False);
      Value.Repeated := False;
      return Flyology_TUI.Events.Pressed (Value);
   end Key;

   function Pointer
     (X, Y    : Integer;
      Action  : Flyology_TUI.Events.Mouse_Action;
      Button  : Flyology_TUI.Events.Mouse_Button :=
        Flyology_TUI.Events.Left_Button;
      Wheel_Y : Integer := 0) return Flyology_TUI.Mouse.Local_Event is
     (X        => X,
      Y        => Y,
      Button   => Button,
      Action   => Action,
      Modified => (others => False),
      Wheel_X  => 0,
      Wheel_Y  => Wheel_Y);

   function Painted
     (Width, Height : Natural;
      Glyph         : Wide_Wide_String;
      Style         : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Width, Height, Style);
   begin
      if Width > 0 and then Height > 0 then
         Result.Write (0, 0, Glyph, Style);
      end if;
      return Result;
   end Painted;

   procedure Expect_Capacity
     (Action : not null access procedure;
      Description : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Action.all;
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert (Raised, Description);
   end Expect_Capacity;

   procedure Expect_Structure
     (Action : not null access procedure;
      Description : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Action.all;
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert (Raised, Description);
   end Expect_Structure;

   procedure Test_Empty_Tiny_And_Theme is
      Empty : Chats.Model := Chats.Create (Empty_Messages, 0);
      Plan  : constant Chats.Layout_Plan := Empty.Plan (0);
      View  : constant Chats.Presentation :=
        Empty.Present (Empty_Bodies, 0, Flyology_TUI.Themes.Default);
      Look  : constant Chats.Appearance :=
        Chats.From_Theme (Flyology_TUI.Themes.Charm);
      Item  : Chats.Model := Chats.Create
        ((1 => Message
           (One, Alice, Chats.Assistant, Chats.Streaming)), 2);
   begin
      Empty.Reconcile_Measurements (Empty_Measurements);
      Assert
        (Empty.Is_Empty
         and then Empty.Length = 0
         and then Chats.Width (Plan) = 0
         and then Chats.Height (Plan) = 0
         and then Chats.Required_Body_Count (Plan) = 0
         and then Chats.Frame (View).Width = 0
         and then Chats.Frame (View).Height = 0,
         "empty chat did not remain an empty value");
      Assert
        (Look.Assistant = Flyology_TUI.Themes.Charm.Primary
         and then Look.User = Flyology_TUI.Themes.Charm.Input
         and then Look.Failed = Flyology_TUI.Themes.Charm.Error,
         "theme roles did not map to chat appearance");

      Item.Reconcile_Measurements
        ((1 => (Id => One, Body_Height => 1, Action_Height => 0)));
      declare
         Bodies : constant Chats.Body_Array :=
           (1 =>
              (Id      => One,
               Content => Painted (3, 1, "🙂"),
               Actions => Flyology_TUI.Surfaces.Create (0, 0)));
         Rendered : constant Chats.Presentation :=
           Item.Present
             (Bodies, 3, Flyology_TUI.Themes.Charm, Has_Focus => True);
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Chats.Frame (Rendered);
      begin
         Assert
           (Frame.Width = 3 and then Frame.Height = 2,
            "tiny wide-character chat has the wrong extent");
         Assert
           (Frame.Element (0, 0).Appearance =
              Flyology_TUI.Themes.Charm.Focused,
            "chat presentation did not apply its borrowed theme");
         for X in 0 .. Frame.Width - 1 loop
            Assert
              (not Frame.Element (X, 0).Continuation
               or else X > 0,
               "wide header left an orphan continuation cell");
         end loop;
      end;
   end Test_Empty_Tiny_And_Theme;

   procedure Test_Virtualization_And_Mixed_Heights is
      Item : Chats.Model := Chats.Create
        ((Message (One, Alice, Chats.User),
          Message (Two, Ada_Bot, Chats.Assistant, Chats.Streaming),
          Message (Three, Runtime, Chats.Tool),
          Message (Four, Alice, Chats.Notice)),
         Viewport_Rows => 5);
      Changed : Boolean;
   begin
      Item.Reconcile_Measurements
        (((One, 2, 1),
          (Two, 5, 0),
          (Three, 1, 0),
          (Four, 3, 0)));
      Assert
        (Item.Content_Height = 16
         and then Item.First_Visible_Cell = 11
         and then Item.Follows_Tail,
         "mixed heights did not anchor the viewport to the tail");
      declare
         Tail : constant Chats.Layout_Plan := Item.Plan (24);
      begin
         Assert
           (Chats.Required_Body_Count (Tail) = 2
            and then Chats.Required_Body_Id (Tail, 1) = Three
            and then Chats.Required_Body_Id (Tail, 2) = Four,
            "tail plan did not virtualize mixed-height messages");
      end;

      Item.Scroll_Cells (Integer'First, Changed);
      Assert
        (Changed and then Item.First_Visible_Cell = 0
         and then not Item.Follows_Tail,
         "extreme upward scroll did not saturate at the transcript start");
      declare
         Head : constant Chats.Layout_Plan := Item.Plan (24);
      begin
         Assert
           (Chats.Required_Body_Count (Head) = 2
            and then Chats.Required_Body_Id (Head, 1) = One
            and then Chats.Required_Body_Id (Head, 2) = Two,
            "head plan did not include the partially visible next message");
      end;

      Item.Scroll_Cells (Integer'Last, Changed);
      Assert
        (Changed and then Item.First_Visible_Cell = 11
         and then Item.Follows_Tail,
         "extreme downward scroll did not saturate at the tail");
   end Test_Virtualization_And_Mixed_Heights;

   procedure Test_Stable_Replacement_And_Unread is
      Item : Chats.Model := Chats.Create
        ((Message (One, Alice, Chats.User),
          Message (Two, Ada_Bot, Chats.Assistant),
          Message (Three, Runtime, Chats.System)),
         Viewport_Rows => 2);

      procedure Duplicate is
      begin
         Item.Set_Messages
           ((Message (One, Alice, Chats.User),
             Message (One, Ada_Bot, Chats.Assistant)));
      end Duplicate;

      procedure Oversized is
      begin
         Item.Set_Messages
           ((Message (One, Alice, Chats.User),
             Message (Two, Alice, Chats.User),
             Message (Three, Alice, Chats.User),
             Message (Four, Alice, Chats.User),
             Message (Five, Alice, Chats.User),
             Message (Six, Alice, Chats.User),
             Message (Seven, Alice, Chats.User)));
      end Oversized;

      procedure Missing_Select is
      begin
         Item.Select_Id (Seven);
      end Missing_Select;
   begin
      Item.Reconcile_Measurements
        (((One, 1, 0), (Two, 3, 1), (Three, 1, 0)));
      Item.Select_Id (Two);
      Item.Set_Follow_Tail (False);
      Item.Set_Messages
        ((Message (Three, Runtime, Chats.System),
          Message (Two, Ada_Bot, Chats.Assistant, Sequence => 9),
          Message (Four, Alice, Chats.Notice)));
      Assert
        (Item.Selected_Id = Two and then Item.Focused_Id = Two
         and then Item.Message_At (2).Sequence = 9
         and then Item.Content_Height = 9
         and then Item.Unread_Count = 1,
         "stable state or measurements did not survive replacement");

      Item.Set_Messages
        ((Message (Three, Runtime, Chats.System),
          Message (Two, Ada_Bot, Chats.Assistant),
          Message (Four, Alice, Chats.Notice)));
      Assert
        (Item.Unread_Count = 1,
         "updating existing stable ids counted as unread");

      Expect_Structure
        (Duplicate'Access, "duplicate message ids were accepted");
      Expect_Capacity
        (Oversized'Access, "message capacity overflow was accepted");
      Expect_Structure
        (Missing_Select'Access, "an unknown selected id was accepted");
      Assert
        (Item.Length = 3 and then Item.Selected_Id = Two
         and then Item.Unread_Count = 1,
         "failed replacement mutated stable chat state");

      Item.Set_Follow_Tail (True);
      Assert
        (Item.Unread_Count = 0 and then Item.Follows_Tail,
         "following the tail did not mark new messages seen");
   end Test_Stable_Replacement_And_Unread;

   procedure Test_Atomic_Measurements_And_Dimensions is
      Item : Chats.Model := Chats.Create
        ((Message (One, Alice, Chats.User),
          Message (Two, Ada_Bot, Chats.Assistant)), 3);

      procedure Missing is
      begin
         Item.Reconcile_Measurements
           ((1 => (One, 4, 0)));
      end Missing;

      procedure Duplicate is
      begin
         Item.Reconcile_Measurements
           (((One, 4, 0), (One, 2, 0)));
      end Duplicate;

      procedure Overflow_Height is
      begin
         Item.Reconcile_Measurements
           (((One, Natural'Last, 0), (Two, 1, 0)));
      end Overflow_Height;

      procedure Overflow_Frame is
         Discard : Chats.Layout_Plan;
      begin
         Item.Set_Viewport_Rows (Natural'Last);
         Discard := Item.Plan (2);
      end Overflow_Frame;

      procedure Replacement_Overflow is
      begin
         Item.Set_Messages
           ((Message (One, Alice, Chats.User),
             Message (Two, Ada_Bot, Chats.Assistant),
             Message (Three, Runtime, Chats.System)));
      end Replacement_Overflow;
   begin
      Item.Reconcile_Measurements
        (((One, 2, 0), (Two, 1, 1)));
      Assert (Item.Content_Height = 6, "baseline measurement total is wrong");
      Expect_Structure
        (Missing'Access, "missing measurement was accepted");
      Expect_Structure
        (Duplicate'Access, "duplicate measurement was accepted");
      Expect_Capacity
        (Overflow_Height'Access, "height addition overflow was accepted");
      Assert
        (Item.Content_Height = 6,
         "failed measurement reconciliation mutated heights");

      Item.Reconcile_Measurements
        (((One, 0, 0), (Two, Natural'Last - 2, 0)));
      Assert
        (Item.Content_Height = Natural'Last,
         "near-boundary measurement total was rejected");
      Expect_Capacity
        (Replacement_Overflow'Access,
         "replacement content-height overflow was accepted");
      Assert
        (Item.Length = 2 and then Item.Content_Height = Natural'Last,
         "failed replacement overflow mutated messages or heights");
      Expect_Capacity
        (Overflow_Frame'Access, "frame cell product overflow was accepted");
   end Test_Atomic_Measurements_And_Dimensions;

   procedure Test_Presentation_Borrowing_And_Validation is
      Item : Chats.Model := Chats.Create
        ((Message (One, Alice, Chats.User),
          Message (Two, Ada_Bot, Chats.Assistant, Chats.Failed)), 6);
      First_Body : Flyology_TUI.Surfaces.Surface := Painted (12, 2, "A");
      Bodies : Chats.Body_Array :=
        ((Id      => One,
          Content => First_Body,
          Actions => Painted (12, 1, "reply")),
         (Id      => Two,
          Content => Painted (12, 1, "B"),
          Actions => Flyology_TUI.Surfaces.Create (0, 0)));
      Footer : constant Flyology_TUI.Surfaces.Surface :=
        Painted (12, 1, "footer");
      Composer : constant Flyology_TUI.Surfaces.Surface :=
        Painted (12, 1, "> compose");
      Saved : Chats.Presentation;

      procedure Missing_Body is
         Short : constant Chats.Body_Array := (1 => Bodies (1));
         Discard : Chats.Presentation;
      begin
         Discard := Item.Present
           (Short, 12, Footer, Composer, Flyology_TUI.Themes.Default);
      end Missing_Body;

      procedure Duplicate_Body is
         Wrong : constant Chats.Body_Array :=
           (Bodies (1), Bodies (1));
         Discard : Chats.Presentation;
      begin
         Discard := Item.Present
           (Wrong, 12, Footer, Composer, Flyology_TUI.Themes.Default);
      end Duplicate_Body;

      procedure Wrong_Height is
         Wrong : Chats.Body_Array := Bodies;
         Discard : Chats.Presentation;
      begin
         Wrong (1).Content := Painted (12, 1, "short");
         Discard := Item.Present
           (Wrong, 12, Footer, Composer, Flyology_TUI.Themes.Default);
      end Wrong_Height;
   begin
      Item.Reconcile_Measurements
        (((One, 2, 1), (Two, 1, 0)));
      Saved := Item.Present
        (Bodies, 12, Footer, Composer, Flyology_TUI.Themes.Charm,
         Has_Focus => True);
      Assert
        (Chats.Frame (Saved).Width = 12
         and then Chats.Frame (Saved).Height = 8
         and then Chats.Has_Message (Saved, One)
         and then Chats.Has_Action_Region (Saved, One)
         and then not Chats.Has_Action_Region (Saved, Two)
         and then Chats.Has_Footer (Chats.Layout (Saved))
         and then Chats.Has_Composer (Chats.Layout (Saved)),
         "presentation omitted external regions or extent");

      First_Body.Write (0, 0, "Z");
      Bodies (1).Content.Write (0, 0, "Z");
      Assert
        (Text.To_Wide_Wide_String
           (Chats.Frame (Saved).Element (0, 1).Glyph) = "A",
         "presentation retained a caller body instead of composing it");

      Expect_Structure
        (Missing_Body'Access, "missing visible body was accepted");
      Expect_Structure
        (Duplicate_Body'Access, "duplicate visible body was accepted");
      Expect_Structure
        (Wrong_Height'Access, "wrong measured body height was accepted");
   end Test_Presentation_Borrowing_And_Validation;

   procedure Test_Keyboard_Mouse_And_Pass_Through is
      Item : Chats.Model := Chats.Create
        ((Message (One, Alice, Chats.User),
          Message (Two, Ada_Bot, Chats.Assistant)), 5);
      Bodies : constant Chats.Body_Array :=
        ((One, Painted (10, 1, "one"), Painted (10, 1, "act")),
         (Two, Painted (10, 1, "two"),
          Flyology_TUI.Surfaces.Create (0, 0)));
      View : Chats.Presentation;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Body_Area : Flyology_TUI.Geometry.Rectangle;
      Action_Area : Flyology_TUI.Geometry.Rectangle;
      Header : Flyology_TUI.Geometry.Rectangle;
   begin
      Item.Reconcile_Measurements
        (((One, 1, 1), (Two, 1, 0)));
      Item.Set_Follow_Tail (False);
      View := Item.Present (Bodies, 10, Flyology_TUI.Themes.Charm);

      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Result.Handled and then Result.Changed
         and then Item.Focused_Id = Two,
         "keyboard navigation did not move chat focus");
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Activated and then Item.Selected_Id = Two,
         "keyboard activation did not select the focused message");

      Body_Area := Chats.Body_Region (View, One);
      Result := Item.Handle
        (Pointer
           (Body_Area.X, Body_Area.Y,
            Flyology_TUI.Events.Mouse_Click),
         View);
      Assert
        (not Result.Handled,
         "chat consumed an event belonging to a heterogeneous body");

      Action_Area := Chats.Action_Region (View, One);
      Result := Item.Handle
        (Pointer
           (Action_Area.X, Action_Area.Y,
            Flyology_TUI.Events.Mouse_Click),
         View);
      Assert
        (not Result.Handled,
         "chat consumed an event belonging to message actions");

      Header := Chats.Header_Region (View, One);
      Result := Item.Handle
        (Pointer
           (Header.X, Header.Y,
            Flyology_TUI.Events.Mouse_Click),
         View);
      Assert
        (Result.Handled and then Result.Activated
         and then Result.Focus_Requested and then Item.Selected_Id = One,
         "header click did not focus and select its stable message");

      Result := Item.Handle
        (Pointer
           (0, 0, Flyology_TUI.Events.Mouse_Wheel,
            Button => Flyology_TUI.Events.No_Button,
            Wheel_Y => Integer'Last),
         View);
      Assert
        (Result.Handled and then not Item.Follows_Tail,
         "extreme transcript wheel input was not handled safely");
      Result := Item.Handle
        (Pointer
           (0, 0, Flyology_TUI.Events.Mouse_Wheel,
            Button => Flyology_TUI.Events.No_Button,
            Wheel_Y => 0),
         View);
      Assert
        (not Result.Handled,
         "zero wheel input reported a chat change");
   end Test_Keyboard_Mouse_And_Pass_Through;

begin
   Test_Empty_Tiny_And_Theme;
   Test_Virtualization_And_Mixed_Heights;
   Test_Stable_Replacement_And_Unread;
   Test_Atomic_Measurements_And_Dimensions;
   Test_Presentation_Borrowing_And_Validation;
   Test_Keyboard_Mouse_And_Pass_Through;
   Ada.Text_IO.Put_Line ("chat tests passed");
end Chat_Tests;
