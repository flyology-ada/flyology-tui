package body Flyology_TUI.Components.Windows is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Flyology_TUI.Geometry.Rectangle;

   function Chrome_Style
     (Value : Flyology_TUI.Styles.Style) return Flyology_TUI.Styles.Style
   is
      Result : Flyology_TUI.Styles.Style := Value;
   begin
      Result.Italic := False;
      Result.Underline := False;
      Result.Blink := False;
      Result.Strikethrough := False;
      return Result;
   end Chrome_Style;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance
   is
     (Frame         => Chrome_Style (Theme.Border),
      Focused_Frame => Chrome_Style (Theme.Focused),
      Title         => Theme.Primary,
      Focused_Title => Theme.Focused,
      Close         => Theme.Error,
      Content       => Theme.Primary,
      Disabled      => Theme.Muted);

   function Safe_Add (Left, Right : Integer) return Integer is
   begin
      if Right > 0 and then Left > Integer'Last - Right then
         return Integer'Last;
      elsif Right < 0 and then Left < Integer'First - Right then
         return Integer'First;
      else
         return Left + Right;
      end if;
   end Safe_Add;

   function Safe_Subtract (Left, Right : Integer) return Integer is
   begin
      if Right > 0 and then Left < Integer'First + Right then
         return Integer'First;
      elsif Right < 0 and then Left > Integer'Last + Right then
         return Integer'Last;
      else
         return Left - Right;
      end if;
   end Safe_Subtract;

   function Safe_Negate (Value : Integer) return Integer is
     (if Value = Integer'First then Integer'Last else -Value);

   function Shifted_Length
     (Value : Positive;
      Amount : Integer) return Positive
   is
   begin
      if Amount >= 0 then
         if Natural (Amount) > Natural'Last - Value then
            return Positive'Last;
         else
            return Value + Natural (Amount);
         end if;
      elsif Amount = Integer'First or else Natural (-Amount) >= Value then
         return 1;
      else
         return Value - Natural (-Amount);
      end if;
   end Shifted_Length;

   function Create
     (X, Y                : Integer;
      Width, Height       : Positive;
      Minimum_Width       : Positive := 4;
      Minimum_Height      : Positive := 3;
      Closable            : Boolean := True;
      Movable             : Boolean := True;
      Resizable           : Boolean := True) return Model
   is
     (Area           =>
        (X, Y,
         Natural'Max (Width, Minimum_Width),
         Natural'Max (Height, Minimum_Height)),
      Minimum_Width  => Minimum_Width,
      Minimum_Height => Minimum_Height,
      Can_Close      => Closable,
      Can_Move       => Movable,
      Can_Resize     => Resizable,
      others         => <>);

   function Bounds (Item : Model) return Flyology_TUI.Geometry.Rectangle is
     (Item.Area);

   function Client_Region
     (Item : Model) return Flyology_TUI.Geometry.Rectangle
   is
     (X      => Safe_Add (Item.Area.X, 1),
      Y      => Safe_Add (Item.Area.Y, 1),
      Width  => (if Item.Area.Width > 2 then Item.Area.Width - 2 else 0),
      Height => (if Item.Area.Height > 2 then Item.Area.Height - 2 else 0));

   function Client_Origin
     (Item : Model) return Flyology_TUI.Geometry.Point
   is ((X => Safe_Add (Item.Area.X, 1),
       Y => Safe_Add (Item.Area.Y, 1)));

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
         --  Cancel the semantic operation, but retain capture ownership until
         --  the matching left release can be reported to the application.
         Item.Active := Idle;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   procedure Clamp
     (Area           : in out Flyology_TUI.Geometry.Rectangle;
      Minimum_Width  : Positive;
      Minimum_Height : Positive;
      Workspace      : Flyology_TUI.Geometry.Rectangle)
   is
      Min_Width : Positive := Minimum_Width;
      Min_Height : Positive := Minimum_Height;
      Max_X : Integer;
      Max_Y : Integer;
   begin
      if Workspace.Width = 0 or else Workspace.Height = 0 then
         Area.X := Workspace.X;
         Area.Y := Workspace.Y;
         Area.Width := Natural'Max (Area.Width, Minimum_Width);
         Area.Height := Natural'Max (Area.Height, Minimum_Height);
         return;
      end if;

      Min_Width := Natural'Min (Minimum_Width, Workspace.Width);
      Min_Height := Natural'Min (Minimum_Height, Workspace.Height);
      Area.Width :=
        Natural'Max
          (Min_Width, Natural'Min (Area.Width, Workspace.Width));
      Area.Height :=
        Natural'Max
          (Min_Height, Natural'Min (Area.Height, Workspace.Height));

      Max_X := Safe_Add (Workspace.X, Integer (Workspace.Width - Area.Width));
      Max_Y :=
        Safe_Add (Workspace.Y, Integer (Workspace.Height - Area.Height));
      Area.X := Integer'Max (Workspace.X, Integer'Min (Area.X, Max_X));
      Area.Y := Integer'Max (Workspace.Y, Integer'Min (Area.Y, Max_Y));
   end Clamp;

   procedure Constrain_To
     (Item      : in out Model;
      Workspace : Flyology_TUI.Geometry.Rectangle) is
   begin
      Clamp
        (Item.Area, Item.Minimum_Width, Item.Minimum_Height, Workspace);
      Item.Active := Idle;
   end Constrain_To;

   function Close_Hit
     (Area : Flyology_TUI.Geometry.Rectangle;
      Point : Flyology_TUI.Geometry.Point) return Boolean
   is
      Close_X : constant Integer :=
        Safe_Add
          (Area.X,
           Integer (if Area.Width > 1 then Area.Width - 2 else 0));
   begin
      return Area.Width > 1
        and then Point.Y = Area.Y
        and then Point.X = Close_X;
   end Close_Hit;

   function Operation_At
     (Item  : Model;
      Point : Flyology_TUI.Geometry.Point) return Operation
   is
      Left   : constant Boolean := Point.X = Item.Area.X;
      Top    : constant Boolean := Point.Y = Item.Area.Y;
      Right  : constant Boolean :=
        Point.X = Safe_Add (Item.Area.X, Integer (Item.Area.Width - 1));
      Bottom : constant Boolean :=
        Point.Y = Safe_Add (Item.Area.Y, Integer (Item.Area.Height - 1));
      North_Handle : constant Boolean :=
        Top and then Point.X = Safe_Add (Item.Area.X, 1);
   begin
      if Item.Can_Close and then Close_Hit (Item.Area, Point) then
         return Closing;
      elsif Item.Can_Resize then
         if Top and Left then
            return Resize_North_West;
         elsif Top and Right then
            return Resize_North_East;
         elsif Bottom and Left then
            return Resize_South_West;
         elsif Bottom and Right then
            return Resize_South_East;
         elsif North_Handle then
            return Resize_North;
         elsif Bottom then
            return Resize_South;
         elsif Left then
            return Resize_West;
         elsif Right then
            return Resize_East;
         end if;
      end if;
      if Item.Can_Move and then Top then
         return Moving;
      end if;
      return Idle;
   end Operation_At;

   procedure Apply_Drag
     (Item      : in out Model;
      Point     : Flyology_TUI.Geometry.Point;
      Workspace : Flyology_TUI.Geometry.Rectangle)
   is
      DX : constant Integer := Safe_Subtract (Point.X, Item.Press_Point.X);
      DY : constant Integer := Safe_Subtract (Point.Y, Item.Press_Point.Y);
      Result : Flyology_TUI.Geometry.Rectangle := Item.Press_Area;
      New_Width : Positive;
      New_Height : Positive;
      Effective_Minimum_Width : constant Positive :=
        (if Workspace.Width = 0
         then Item.Minimum_Width
         else Natural'Min (Item.Minimum_Width, Workspace.Width));
      Effective_Minimum_Height : constant Positive :=
        (if Workspace.Height = 0
         then Item.Minimum_Height
         else Natural'Min (Item.Minimum_Height, Workspace.Height));
   begin
      case Item.Active is
         when Moving =>
            Result.X := Safe_Add (Result.X, DX);
            Result.Y := Safe_Add (Result.Y, DY);
         when Resize_East | Resize_North_East | Resize_South_East =>
            Result.Width := Shifted_Length (Positive (Result.Width), DX);
         when Resize_West | Resize_North_West | Resize_South_West =>
            New_Width :=
              Natural'Max
                (Effective_Minimum_Width,
                 Shifted_Length
                   (Positive (Result.Width), Safe_Negate (DX)));
            Result.X := Safe_Add
              (Result.X, Integer (Result.Width - New_Width));
            Result.Width := New_Width;
         when others => null;
      end case;
      case Item.Active is
         when Resize_South | Resize_South_West | Resize_South_East =>
            Result.Height := Shifted_Length (Positive (Result.Height), DY);
         when Resize_North | Resize_North_West | Resize_North_East =>
            New_Height :=
              Natural'Max
                (Effective_Minimum_Height,
                 Shifted_Length
                   (Positive (Result.Height), Safe_Negate (DY)));
            Result.Y := Safe_Add
              (Result.Y, Integer (Result.Height - New_Height));
            Result.Height := New_Height;
         when others => null;
      end case;
      Clamp (Result, Item.Minimum_Width, Item.Minimum_Height, Workspace);
      Item.Area := Result;
   end Apply_Drag;

   function Handle
     (Item      : in out Model;
      Event     : Flyology_TUI.Mouse.Local_Event;
      Workspace : Flyology_TUI.Geometry.Rectangle)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Point : constant Flyology_TUI.Geometry.Point := (Event.X, Event.Y);
      Before : constant Flyology_TUI.Geometry.Rectangle := Item.Area;
   begin
      if Event.Action = Flyology_TUI.Events.Mouse_Release
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then Item.Capturing
      then
         Result.Handled := True;
         Result.Capture :=
           Flyology_TUI.Components.Interactions.Release_Capture;
         Result.Activated :=
           Item.Enabled
           and then Item.Active = Closing
           and then Close_Hit (Item.Area, Point);
         Item.Capturing := False;
         Item.Active := Idle;
      elsif not Item.Enabled then
         null;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Click
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then Flyology_TUI.Geometry.Contains (Item.Area, Point)
      then
         Item.Has_Focus := True;
         Item.Active := Operation_At (Item, Point);
         Item.Press_Point := Point;
         Item.Press_Area := Item.Area;
         Result.Handled := True;
         Result.Focus_Requested := True;
         if Item.Active /= Idle then
            Item.Capturing := True;
            Result.Capture :=
              Flyology_TUI.Components.Interactions.Acquire_Capture;
         end if;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Drag
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then Item.Active /= Idle
      then
         Result.Handled := True;
         if Item.Active /= Closing then
            Apply_Drag (Item, Point, Workspace);
         end if;
      end if;
      Result.Changed := Item.Area /= Before;
      return Result;
   end Handle;

   function Handle
     (Item      : in out Model;
      Event     : Flyology_TUI.Events.Terminal_Event;
      Workspace : Flyology_TUI.Geometry.Rectangle)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Before : constant Flyology_TUI.Geometry.Rectangle := Item.Area;
      Step : Integer := 1;
      Delta_X, Delta_Y : Integer := 0;
   begin
      if not Item.Enabled
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
      then
         return Result;
      end if;
      if Event.Key.Modified.Shift then
         Step := 5;
      end if;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Left_Key  => Delta_X := -Step;
         when Flyology_TUI.Events.Arrow_Right_Key => Delta_X := Step;
         when Flyology_TUI.Events.Arrow_Up_Key    => Delta_Y := -Step;
         when Flyology_TUI.Events.Arrow_Down_Key  => Delta_Y := Step;
         when others => return Result;
      end case;

      if Event.Key.Modified.Alt and then Item.Can_Move then
         Item.Area.X := Safe_Add (Item.Area.X, Delta_X);
         Item.Area.Y := Safe_Add (Item.Area.Y, Delta_Y);
      elsif Event.Key.Modified.Control and then Item.Can_Resize then
         if Delta_X /= 0 then
            Item.Area.Width := Shifted_Length
              (Positive (Item.Area.Width), Delta_X);
         end if;
         if Delta_Y /= 0 then
            Item.Area.Height := Shifted_Length
              (Positive (Item.Area.Height), Delta_Y);
         end if;
      else
         return Result;
      end if;
      Clamp
        (Item.Area, Item.Minimum_Width, Item.Minimum_Height, Workspace);
      Result.Handled := True;
      Result.Changed := Item.Area /= Before;
      return Result;
   end Handle;

   procedure Update
     (Item      : in out Model;
      Event     : Flyology_TUI.Mouse.Local_Event;
      Workspace : Flyology_TUI.Geometry.Rectangle)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event, Workspace);
   begin
      null;
   end Update;

   procedure Update
     (Item      : in out Model;
      Event     : Flyology_TUI.Events.Terminal_Event;
      Workspace : Flyology_TUI.Geometry.Rectangle)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event, Workspace);
   begin
      null;
   end Update;

   function Render
     (Item       : Model;
      Title      : Wide_Wide_String;
      Content    : Flyology_TUI.Surfaces.Surface;
      Workspace  : Flyology_TUI.Geometry.Rectangle;
      Appearance : Windows.Appearance)
      return Flyology_TUI.Surfaces.Surface is
     (Render
        (Item, Title, Content, Workspace, Appearance,
         Flyology_TUI.Skins.Charm_Default_Skin.Window));

   function Render
     (Item       : Model;
      Title      : Wide_Wide_String;
      Content    : Flyology_TUI.Surfaces.Surface;
      Workspace  : Flyology_TUI.Geometry.Rectangle;
      Appearance : Windows.Appearance;
      Chrome     : Flyology_TUI.Skins.Window_Chrome)
      return Flyology_TUI.Surfaces.Surface
   is
      Frame_Style : constant Flyology_TUI.Styles.Style :=
        (if not Item.Enabled
         then Appearance.Disabled
         elsif Item.Has_Focus
         then Appearance.Focused_Frame
         else Appearance.Frame);
      Title_Style : constant Flyology_TUI.Styles.Style :=
        (if not Item.Enabled
         then Appearance.Disabled
         elsif Item.Has_Focus
         then Appearance.Focused_Title
         else Appearance.Title);
      Content_Style : constant Flyology_TUI.Styles.Style :=
        (if Item.Enabled then Appearance.Content else Appearance.Disabled);
      Close_Style : constant Flyology_TUI.Styles.Style :=
        (if Item.Enabled then Appearance.Close else Appearance.Disabled);
      Result : Flyology_TUI.Surfaces.Surface;
      Window : Flyology_TUI.Surfaces.Surface;
      Client_Layer : Flyology_TUI.Surfaces.Surface;
      Title_Layer : Flyology_TUI.Surfaces.Surface;
      Client_Width : constant Natural :=
        (if Item.Area.Width > 2 then Item.Area.Width - 2 else 0);
      Client_Height : constant Natural :=
        (if Item.Area.Height > 2 then Item.Area.Height - 2 else 0);
      Title_Width : constant Natural :=
        (if Item.Can_Close
         then (if Item.Area.Width > 4 then Item.Area.Width - 4 else 0)
         else (if Item.Area.Width > 3 then Item.Area.Width - 3 else 0));
      Offset_X : constant Integer := Safe_Subtract (Item.Area.X, Workspace.X);
      Offset_Y : constant Integer := Safe_Subtract (Item.Area.Y, Workspace.Y);

      procedure Put_Shadow (X, Y : Long_Long_Integer) is
      begin
         if X >= 0 and then Y >= 0
           and then X < Long_Long_Integer (Result.Width)
           and then Y < Long_Long_Integer (Result.Height)
         then
            Result.Put
              (Natural (X), Natural (Y), " ", Chrome.Frame.Shadow);
         end if;
      end Put_Shadow;
   begin
      if Workspace.Width /= 0
        and then Workspace.Height > Natural'Last / Workspace.Width
      then
         raise Flyology_TUI.Components.Capacity_Error with
           "window workspace exceeds addressable cell capacity";
      end if;
      if Item.Area.Width /= 0
        and then Item.Area.Height > Natural'Last / Item.Area.Width
      then
         raise Flyology_TUI.Components.Capacity_Error with
           "window frame exceeds addressable cell capacity";
      end if;
      Result := Flyology_TUI.Surfaces.Create
        (Workspace.Width, Workspace.Height, Content_Style);
      Window := Flyology_TUI.Surfaces.Create
        (Item.Area.Width, Item.Area.Height, Content_Style);

      declare
         Shadow_X : constant Natural :=
           Natural'Min (Chrome.Frame.Shadow_X, Workspace.Width);
         Shadow_Y : constant Natural :=
           Natural'Min (Chrome.Frame.Shadow_Y, Workspace.Height);
      begin
         if Shadow_X > 0 then
            for DX in 0 .. Shadow_X - 1 loop
               for Y in 0 .. Item.Area.Height - 1 loop
                  Put_Shadow
                    (Long_Long_Integer (Offset_X)
                       + Long_Long_Integer (Item.Area.Width)
                       + Long_Long_Integer (DX),
                     Long_Long_Integer (Offset_Y)
                       + Long_Long_Integer (Shadow_Y)
                       + Long_Long_Integer (Y));
               end loop;
            end loop;
         end if;
         if Shadow_Y > 0 then
            for DY in 0 .. Shadow_Y - 1 loop
               for X in 0 .. Item.Area.Width - 1 loop
                  Put_Shadow
                    (Long_Long_Integer (Offset_X)
                       + Long_Long_Integer (Shadow_X)
                       + Long_Long_Integer (X),
                     Long_Long_Integer (Offset_Y)
                       + Long_Long_Integer (Item.Area.Height)
                       + Long_Long_Integer (DY));
               end loop;
            end loop;
         end if;
      end;

      if Item.Area.Height > 0 then
         for X in 0 .. Item.Area.Width - 1 loop
            Window.Put
              (X,
               0,
               (if X = 0 then (1 => Chrome.Frame.Border.Top_Left)
                elsif X + 1 = Item.Area.Width
                then (1 => Chrome.Frame.Border.Top_Right)
                else (1 => Chrome.Frame.Border.Horizontal)),
               Frame_Style);
            if Item.Area.Height > 1 then
               Window.Put
                 (X,
                  Item.Area.Height - 1,
                  (if X = 0 then (1 => Chrome.Frame.Border.Bottom_Left)
                   elsif X + 1 = Item.Area.Width
                   then (1 => Chrome.Frame.Border.Bottom_Right)
                   else (1 => Chrome.Frame.Border.Horizontal)),
                  Frame_Style);
            end if;
         end loop;
         if Item.Area.Height > 2 then
            for Y in 1 .. Item.Area.Height - 2 loop
               Window.Put
                 (0, Y, (1 => Chrome.Frame.Border.Vertical), Frame_Style);
               if Item.Area.Width > 1 then
                  Window.Put
                    (Item.Area.Width - 1, Y,
                     (1 => Chrome.Frame.Border.Vertical), Frame_Style);
               end if;
            end loop;
         end if;
      end if;

      if Title_Width > 0 and then Title'Length > 0 then
         Title_Layer :=
           Flyology_TUI.Surfaces.Create (Title_Width, 1, Frame_Style);
         Title_Layer.Write (0, 0, Title, Title_Style);
         Window.Overlay_Clipped (Title_Layer, 2, 0);
      end if;
      if Item.Can_Close and then Item.Area.Width > 1 then
         Window.Put
           (Item.Area.Width - 2, 0, (1 => Chrome.Close), Close_Style);
      end if;
      if Client_Width > 0 and then Client_Height > 0 then
         Client_Layer :=
           Flyology_TUI.Surfaces.Create
             (Client_Width, Client_Height, Content_Style);
         Client_Layer.Overlay_Clipped (Content, 0, 0);
         Window.Overlay_Clipped (Client_Layer, 1, 1);
      end if;
      Result.Overlay_Clipped (Window, Offset_X, Offset_Y);
      return Result;
   end Render;

   function Render
     (Item      : Model;
      Title     : Wide_Wide_String;
      Content   : Flyology_TUI.Surfaces.Surface;
      Workspace : Flyology_TUI.Geometry.Rectangle;
      Skin      : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is (Render
         (Item, Title, Content, Workspace,
          From_Theme (Flyology_TUI.Themes.To_Theme (Skin.Palette)),
          Skin.Window));

   function Render
     (Item      : Model;
      Title     : Wide_Wide_String;
      Content   : Flyology_TUI.Surfaces.Surface;
      Workspace : Flyology_TUI.Geometry.Rectangle;
      Theme     : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, Title, Content, Workspace, From_Theme (Theme)));

end Flyology_TUI.Components.Windows;
