package body Flyology_TUI.Components.Split_Panes is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Flyology_TUI.Layouts.Boxes.Direction;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance
   is
     (Background      => Theme.Primary,
      Divider         => Theme.Border,
      Focused_Divider => Theme.Focused,
      Disabled        => Theme.Muted);

   function Major_Length (Item : Model) return Natural is
     (if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal
      then Item.Columns else Item.Rows);

   function Available (Item : Model) return Natural is
     (if Major_Length (Item) = 0 then 0 else Major_Length (Item) - 1);

   procedure Normalize (Item : in out Model; Desired : Natural) is
      Space : constant Natural := Available (Item);
      First_Lower : constant Natural :=
        Natural'Min (Item.First_Minimum, Space);
      Feasible : constant Boolean :=
        Item.First_Minimum <= Space
        and then Item.Second_Minimum <= Space - Item.First_Minimum;
      Upper : Natural;
   begin
      if Feasible then
         Upper := Space - Item.Second_Minimum;
         Item.First_Value := Natural'Max
           (First_Lower, Natural'Min (Desired, Upper));
      else
         Item.First_Value := First_Lower;
      end if;
   end Normalize;

   function Create
     (Flow           : Orientation;
      Width, Height  : Natural;
      First_Span     : Natural;
      First_Minimum  : Natural := 0;
      Second_Minimum : Natural := 0) return Model
   is
      Result : Model :=
        (Flow_Value     => Flow,
         Columns        => Width,
         Rows           => Height,
         First_Value    => 0,
         First_Minimum  => First_Minimum,
         Second_Minimum => Second_Minimum,
         others         => <>);
   begin
      Normalize (Result, First_Span);
      return Result;
   end Create;

   procedure Resize
     (Item : in out Model;
      Width, Height : Natural)
   is
      Desired : constant Natural := Item.First_Value;
   begin
      Item.Columns := Width;
      Item.Rows := Height;
      Normalize (Item, Desired);
      --  Geometry changes cancel divider movement without relinquishing an
      --  already-acquired application capture.
      Item.Dragging := False;
   end Resize;

   function First_Region
     (Item : Model) return Flyology_TUI.Geometry.Rectangle
   is
     (if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal
      then
        (X => 0, Y => 0, Width => Item.First_Value, Height => Item.Rows)
      else
        (X => 0, Y => 0, Width => Item.Columns, Height => Item.First_Value));

   function Divider_Region
     (Item : Model) return Flyology_TUI.Geometry.Rectangle
   is
     (if Major_Length (Item) = 0 then (0, 0, 0, 0)
      elsif Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal
      then (X => Integer (Item.First_Value), Y => 0,
            Width => 1, Height => Item.Rows)
      else (X => 0, Y => Integer (Item.First_Value),
            Width => Item.Columns, Height => 1));

   function Second_Region
     (Item : Model) return Flyology_TUI.Geometry.Rectangle
   is
      Space : constant Natural := Available (Item);
   begin
      if Major_Length (Item) = 0 then
         return (0, 0, 0, 0);
      elsif Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal then
         return
           (X      => Integer (Item.First_Value + 1),
            Y      => 0,
            Width  => Space - Item.First_Value,
            Height => Item.Rows);
      else
         return
           (X      => 0,
            Y      => Integer (Item.First_Value + 1),
            Width  => Item.Columns,
            Height => Space - Item.First_Value);
      end if;
   end Second_Region;

   function First_Span (Item : Model) return Natural is (Item.First_Value);

   procedure Focus (Item : in out Model) is
   begin
      Item.Has_Focus := True;
   end Focus;

   procedure Blur (Item : in out Model) is
   begin
      Item.Has_Focus := False;
   end Blur;

   function Focused (Item : Model) return Boolean is (Item.Has_Focus);

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
      if not Enabled then
         Item.Dragging := False;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   function Pointer_Span
     (Item  : Model;
      Event : Flyology_TUI.Mouse.Local_Event) return Natural
   is
      Value : constant Integer :=
        (if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal
         then Event.X else Event.Y);
   begin
      if Value <= 0 then
         return 0;
      else
         return Natural (Value);
      end if;
   end Pointer_Span;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Before : constant Natural := Item.First_Value;
      Point : constant Flyology_TUI.Geometry.Point := (Event.X, Event.Y);
   begin
      if Event.Action = Flyology_TUI.Events.Mouse_Release
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then Item.Capturing
      then
         Item.Dragging := False;
         Item.Capturing := False;
         Result.Handled := True;
         Result.Capture :=
           Flyology_TUI.Components.Interactions.Release_Capture;
      elsif not Item.Enabled then
         null;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Click
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then Flyology_TUI.Geometry.Contains (Divider_Region (Item), Point)
      then
         Item.Dragging := True;
         Item.Capturing := True;
         Item.Has_Focus := True;
         Result.Handled := True;
         Result.Focus_Requested := True;
         Result.Capture :=
           Flyology_TUI.Components.Interactions.Acquire_Capture;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Drag
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then Item.Dragging
      then
         Normalize (Item, Pointer_Span (Item, Event));
         Result.Handled := True;
      end if;
      Result.Changed := Item.First_Value /= Before;
      return Result;
   end Handle;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Before : constant Natural := Item.First_Value;
      Step : constant Natural :=
        (if Event.Kind = Flyology_TUI.Events.Key_Press
         and then Event.Key.Modified.Shift then 5 else 1);
      Desired : Natural := Item.First_Value;
   begin
      if not Item.Enabled
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
      then
         return Result;
      end if;
      if (Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal
          and then Event.Key.Kind = Flyology_TUI.Events.Arrow_Left_Key)
        or else
         (Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Vertical
          and then Event.Key.Kind = Flyology_TUI.Events.Arrow_Up_Key)
      then
         Desired := (if Step >= Desired then 0 else Desired - Step);
      elsif (Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal
             and then Event.Key.Kind = Flyology_TUI.Events.Arrow_Right_Key)
        or else
            (Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Vertical
             and then Event.Key.Kind = Flyology_TUI.Events.Arrow_Down_Key)
      then
         Desired :=
           (if Step > Natural'Last - Desired then Natural'Last
            else Desired + Step);
      else
         return Result;
      end if;
      Normalize (Item, Desired);
      Result.Handled := True;
      Result.Changed := Item.First_Value /= Before;
      return Result;
   end Handle;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
   begin
      null;
   end Update;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
   begin
      null;
   end Update;

   function Render
     (Item       : Model;
      First      : Flyology_TUI.Surfaces.Surface;
      Second     : Flyology_TUI.Surfaces.Surface;
      Appearance : Split_Panes.Appearance)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface;
      First_Area : constant Flyology_TUI.Geometry.Rectangle :=
        First_Region (Item);
      Second_Area : constant Flyology_TUI.Geometry.Rectangle :=
        Second_Region (Item);
      Divider_Area : constant Flyology_TUI.Geometry.Rectangle :=
        Divider_Region (Item);
      Divider_Style : constant Flyology_TUI.Styles.Style :=
        (if not Item.Enabled
         then Appearance.Disabled
         elsif Item.Has_Focus
         then Appearance.Focused_Divider
         else Appearance.Divider);
      Background_Style : constant Flyology_TUI.Styles.Style :=
        (if Item.Enabled then Appearance.Background else Appearance.Disabled);
      First_Layer : Flyology_TUI.Surfaces.Surface;
      Second_Layer : Flyology_TUI.Surfaces.Surface;
   begin
      if Item.Columns /= 0
        and then Item.Rows > Natural'Last / Item.Columns
      then
         raise Flyology_TUI.Components.Capacity_Error with
           "split pane exceeds addressable cell capacity";
      end if;
      Result :=
        Flyology_TUI.Surfaces.Create
          (Item.Columns, Item.Rows, Background_Style);
      First_Layer :=
        Flyology_TUI.Surfaces.Create
          (First_Area.Width, First_Area.Height, Background_Style);
      First_Layer.Overlay_Clipped (First, 0, 0);
      Second_Layer :=
        Flyology_TUI.Surfaces.Create
          (Second_Area.Width, Second_Area.Height, Background_Style);
      Second_Layer.Overlay_Clipped (Second, 0, 0);
      Result.Overlay_Clipped (First_Layer, First_Area.X, First_Area.Y);
      Result.Overlay_Clipped (Second_Layer, Second_Area.X, Second_Area.Y);
      if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal then
         if Divider_Area.Width > 0 and then Divider_Area.Height > 0 then
            for Y in 0 .. Divider_Area.Height - 1 loop
               Result.Put (Natural (Divider_Area.X), Y, "│", Divider_Style);
            end loop;
         end if;
      elsif Divider_Area.Width > 0 and then Divider_Area.Height > 0 then
         for X in 0 .. Divider_Area.Width - 1 loop
            Result.Put (X, Natural (Divider_Area.Y), "─", Divider_Style);
         end loop;
      end if;
      return Result;
   end Render;

   function Render
     (Item   : Model;
      First  : Flyology_TUI.Surfaces.Surface;
      Second : Flyology_TUI.Surfaces.Surface;
      Theme  : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, First, Second, From_Theme (Theme)));

end Flyology_TUI.Components.Split_Panes;
