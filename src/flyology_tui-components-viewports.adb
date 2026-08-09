package body Flyology_TUI.Components.Viewports is
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   procedure Clamp (Item : in out Model) is
      Max_X : constant Natural :=
        Flyology_TUI.Surfaces.Width (Item.Content)
        - Natural'Min
            (Flyology_TUI.Surfaces.Width (Item.Content), Item.Columns);
      Max_Y : constant Natural :=
        Flyology_TUI.Surfaces.Height (Item.Content)
        - Natural'Min
            (Flyology_TUI.Surfaces.Height (Item.Content), Item.Rows);
   begin
      Item.X := Natural'Min (Item.X, Max_X);
      Item.Y := Natural'Min (Item.Y, Max_Y);
   end Clamp;

   function Create (Width, Height : Positive) return Model is
     (Content => Flyology_TUI.Surfaces.Create (0, 0),
      Columns => Width,
      Rows    => Height,
      others  => <>);

   procedure Set_Content
     (Item    : in out Model;
      Content : Flyology_TUI.Surfaces.Surface) is
   begin
      Item.Content := Content;
      Clamp (Item);
   end Set_Content;

   procedure Resize (Item : in out Model; Width, Height : Positive) is
   begin
      Item.Columns := Width;
      Item.Rows := Height;
      Clamp (Item);
   end Resize;

   procedure Scroll (Item : in out Model; Delta_X, Delta_Y : Integer) is
      New_X : constant Integer := Integer (Item.X) + Delta_X;
      New_Y : constant Integer := Integer (Item.Y) + Delta_Y;
   begin
      Item.X := Natural (Integer'Max (0, New_X));
      Item.Y := Natural (Integer'Max (0, New_Y));
      Clamp (Item);
   end Scroll;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) is
   begin
      if Event.Kind = Flyology_TUI.Events.Key_Press then
         case Event.Key.Kind is
            when Flyology_TUI.Events.Arrow_Up_Key    => Item.Scroll (0, -1);
            when Flyology_TUI.Events.Arrow_Down_Key  => Item.Scroll (0, 1);
            when Flyology_TUI.Events.Arrow_Left_Key  => Item.Scroll (-1, 0);
            when Flyology_TUI.Events.Arrow_Right_Key => Item.Scroll (1, 0);
            when Flyology_TUI.Events.Page_Up_Key =>
               Item.Scroll (0, -Item.Rows);
            when Flyology_TUI.Events.Page_Down_Key =>
               Item.Scroll (0, Item.Rows);
            when Flyology_TUI.Events.Home_Key => Item.Y := 0;
            when Flyology_TUI.Events.End_Key =>
               Item.Y := Flyology_TUI.Surfaces.Height (Item.Content);
               Clamp (Item);
            when others => null;
         end case;
      end if;
   end Update;

   function Render (Item : Model) return Flyology_TUI.Surfaces.Surface is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Item.Columns, Item.Rows);
      Source_Width : constant Natural :=
        Flyology_TUI.Surfaces.Width (Item.Content);
      Source_Height : constant Natural :=
        Flyology_TUI.Surfaces.Height (Item.Content);
   begin
      for Y in 0 .. Item.Rows - 1 loop
         exit when Item.Y + Y >= Source_Height;
         for X in 0 .. Item.Columns - 1 loop
            exit when Item.X + X >= Source_Width;
            declare
               Value : constant Flyology_TUI.Surfaces.Cell :=
                 Item.Content.Element (Item.X + X, Item.Y + Y);
            begin
               if not Value.Continuation then
                  Result.Put
                    (X,
                     Y,
                     Flyology_TUI.Surfaces.Text.To_Wide_Wide_String
                       (Value.Glyph),
                     Value.Appearance);
               end if;
            end;
         end loop;
      end loop;
      return Result;
   end Render;

   function X_Offset (Item : Model) return Natural is (Item.X);
   function Y_Offset (Item : Model) return Natural is (Item.Y);

end Flyology_TUI.Components.Viewports;
