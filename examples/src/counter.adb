with Ada.Exceptions;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Application_Events;
with Flyology_TUI.Backends;
with Flyology_TUI.Backends.POSIX;
with Flyology_TUI.Colors;
with Flyology_TUI.Events;
with Flyology_TUI.Layouts;
with Flyology_TUI.Runners;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Transitions;
with Flyology_TUI.Views;

procedure Counter is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Message is (Unused_Message);
   type Command is (No_Command);

   type Model is limited record
      Count  : Integer := 0;
      Width  : Natural := 80;
      Height : Natural := 24;
   end record;

   package Events is new Flyology_TUI.Application_Events (Message);
   package Transitions is new Flyology_TUI.Transitions (Command);

   procedure Initialize
     (Item : in out Model;
      Next : in out Transitions.Transition)
   is
      pragma Unreferenced (Item, Next);
   begin
      null;
   end Initialize;

   procedure Update
     (Item  : in out Model;
      Event : Events.Event;
      Next  : in out Transitions.Transition)
   is
   begin
      case Event.Kind is
         when Events.Application_Message => null;
         when Events.Terminal_Input =>
            case Event.Terminal.Kind is
               when Flyology_TUI.Events.Resize =>
                  Item.Width := Event.Terminal.Width;
                  Item.Height := Event.Terminal.Height;
               when Flyology_TUI.Events.Interrupt =>
                  Transitions.Quit (Next);
               when Flyology_TUI.Events.Key_Press =>
                  case Event.Terminal.Key.Kind is
                     when Flyology_TUI.Events.Arrow_Up_Key =>
                        Item.Count := Item.Count + 1;
                     when Flyology_TUI.Events.Arrow_Down_Key =>
                        Item.Count := Item.Count - 1;
                     when Flyology_TUI.Events.Text_Key =>
                        declare
                           Key : constant Wide_Wide_String :=
                             Text.To_Wide_Wide_String
                               (Event.Terminal.Key.Value);
                        begin
                           if Key = "q"
                             or else
                               (Key = "c"
                                and then Event.Terminal.Key.Modified.Control)
                           then
                              Transitions.Quit (Next);
                           elsif Key = "+" or else Key = "k" then
                              Item.Count := Item.Count + 1;
                           elsif Key = "-" or else Key = "j" then
                              Item.Count := Item.Count - 1;
                           end if;
                        end;
                     when others => null;
                  end case;
               when others => null;
            end case;
      end case;
   end Update;

   function Number_Image (Value : Integer) return Wide_Wide_String is
      Narrow : constant String := Integer'Image (Value);
      Result : Wide_Wide_String (Narrow'Range);
   begin
      for Index in Narrow'Range loop
         Result (Index) :=
           Wide_Wide_Character'Val (Character'Pos (Narrow (Index)));
      end loop;
      return Result;
   end Number_Image;

   function Present (Item : Model) return Flyology_TUI.Views.View is
      Accent : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Emphasized
          (Flyology_TUI.Styles.With_Foreground
             (Flyology_TUI.Styles.Default,
              Flyology_TUI.Colors.Basic
                (Flyology_TUI.Colors.Bright_Magenta)));
      Muted : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Black));
      Heading : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text ("Flyology TUI counter", Accent);
      Count : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text (Number_Image (Item.Count), Accent);
      Help : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text
          ("↑/k/+ increase   ↓/j/- decrease   q quit", Muted);
      Content : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Vertically
          (Heading,
           Flyology_TUI.Layouts.Join_Vertically (Count, Help, Gap => 1),
           Gap => 1,
           Alignment => Flyology_TUI.Layouts.Align_Center);
      Box : constant Flyology_TUI.Layouts.Block :=
        (Padding    => (Top => 1, Right => 2, Bottom => 1, Left => 2),
         Border     => Flyology_TUI.Layouts.Rounded,
         Appearance => Accent,
         Horizontal => Flyology_TUI.Layouts.Align_Center,
         Vertical   => Flyology_TUI.Layouts.Align_Middle,
         others     => <>);
      Result : Flyology_TUI.Views.View :=
        Flyology_TUI.Views.From_Surface
          (Flyology_TUI.Layouts.Render (Box, Content));
   begin
      Result.Alternate_Screen := True;
      Result.Window_Title := Text.To_Unbounded_Wide_Wide_String
        ("Flyology TUI counter");
      return Result;
   end Present;

   procedure Execute
     (Item     : Command;
      Result   : out Message;
      Produced : out Boolean)
   is
      pragma Unreferenced (Item);
   begin
      Result := Unused_Message;
      Produced := False;
   end Execute;

   package Runtime is new Flyology_TUI.Runners
     (Events      => Events,
      Transitions => Transitions,
      Model_Type  => Model,
      Initialize  => Initialize,
      Update      => Update,
      Present     => Present,
      Execute     => Execute);

   State : Model;
   Terminal : Flyology_TUI.Backends.POSIX.POSIX_Backend;
begin
   Runtime.Run (State, Terminal);
exception
   when Error : Flyology_TUI.Backends.Backend_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "counter: " & Ada.Exceptions.Exception_Message (Error));
end Counter;
