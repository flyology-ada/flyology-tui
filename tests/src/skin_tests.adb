with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Color_Profiles;
with Flyology_TUI.Colors;
with Flyology_TUI.Components.Tabs;
with Flyology_TUI.Components.Windows;
with Flyology_TUI.Geometry;
with Flyology_TUI.Layouts;
with Flyology_TUI.Skins;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Skin_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Colors.ANSI_Color;
   use type Flyology_TUI.Colors.Color;
   use type Flyology_TUI.Colors.Color_Kind;
   use type Flyology_TUI.Geometry.Rectangle;
   use type Flyology_TUI.Skins.Skin_Id;
   use type Flyology_TUI.Styles.Style;

   type Tab_Id is (First_Tab, Second_Tab);
   function Id_Of (Item : Tab_Id) return Tab_Id is (Item);
   function Label (Item : Tab_Id) return Wide_Wide_String is
     (case Item is when First_Tab => "One", when Second_Tab => "Two");
   package Tabs is new Flyology_TUI.Components.Tabs
     (Item_Type => Tab_Id, Id_Type => Tab_Id, Id_Of => Id_Of,
      Label => Label, Capacity => 2);

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function Glyph
     (Item : Flyology_TUI.Surfaces.Surface;
      X, Y : Natural) return Wide_Wide_String is
     (Text.To_Wide_Wide_String (Item.Element (X, Y).Glyph));

   procedure Test_Presets is
      Turbo : constant Flyology_TUI.Skins.Skin :=
        Flyology_TUI.Skins.Resolve (Flyology_TUI.Skins.Turbo_Vision);
      ANSI_Background : constant Flyology_TUI.Colors.Color :=
        Flyology_TUI.Color_Profiles.Adapt
          (Turbo.Palette.Content.Background,
           Flyology_TUI.Color_Profiles.ANSI_16);
      Mono_Background : constant Flyology_TUI.Colors.Color :=
        Flyology_TUI.Color_Profiles.Adapt
          (Turbo.Palette.Content.Background,
           Flyology_TUI.Color_Profiles.Monochrome);
   begin
      Assert
        (Flyology_TUI.Skins.Next (Flyology_TUI.Skins.Charm_Default) =
           Flyology_TUI.Skins.Charm_Dark
         and then
           Flyology_TUI.Skins.Next (Flyology_TUI.Skins.Turbo_Vision) =
             Flyology_TUI.Skins.Charm_Default,
         "skin cycling is not deterministic");
      Assert
        (Flyology_TUI.Skins.Label (Flyology_TUI.Skins.Turbo_Vision) =
           "Turbo Vision",
         "skin label drifted");
      Assert
        (Turbo.Palette.Content.Background.Kind = Flyology_TUI.Colors.RGB
         and then Turbo.Palette.Content.Background.Red_Value = 0
         and then Turbo.Palette.Content.Background.Green_Value = 0
         and then Turbo.Palette.Content.Background.Blue_Value = 168
         and then Turbo.Panel.Shadow_X = 1
         and then Turbo.Panel.Shadow_Y = 1,
         "Turbo preset lost its desktop or hard shadow");
      Assert
        (Flyology_TUI.Themes.To_Theme (Turbo.Palette).Primary =
           Turbo.Palette.Content,
         "skin palette no longer collapses through the stable theme");
      Assert
        (ANSI_Background.Kind = Flyology_TUI.Colors.ANSI
         and then ANSI_Background.Name = Flyology_TUI.Colors.Blue
         and then Mono_Background.Kind = Flyology_TUI.Colors.Default_Color,
         "Turbo colors no longer degrade through terminal profiles");
   end Test_Presets;

   procedure Test_Frame_Chrome is
      Turbo : constant Flyology_TUI.Skins.Skin :=
        Flyology_TUI.Skins.Turbo_Vision_Skin;
      Content : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text ("body", Turbo.Palette.Content);
      Frame : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Render
          ((Width => 8, Height => 5,
            Padding => (others => 0),
            Border => Flyology_TUI.Layouts.Square,
            Appearance => Turbo.Palette.Border,
            others => <>),
           Content, Turbo.Panel);
      Intrinsic : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Render
          ((Border => Flyology_TUI.Layouts.Square,
            Appearance => Turbo.Palette.Border,
            others => <>),
           Content, Turbo.Panel);
      Oversized : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Render
          ((Width => 5, Height => 4,
            Border => Flyology_TUI.Layouts.Square,
            Appearance => Turbo.Palette.Border,
            others => <>),
           Flyology_TUI.Surfaces.Create
             (20, 10, Turbo.Palette.Error),
           Turbo.Panel);
   begin
      Assert
        (Glyph (Frame, 0, 0) =
           [1 => Wide_Wide_Character'Val (16#2554#)]
         and then Glyph (Frame, 6, 3) =
           [1 => Wide_Wide_Character'Val (16#255D#)],
         "skin frame did not use double-line structural glyphs");
      Assert
        (Frame.Element (7, 1).Appearance.Background =
           Flyology_TUI.Colors.True_Color (0, 0, 0)
         and then Frame.Element (1, 4).Appearance.Background =
           Flyology_TUI.Colors.True_Color (0, 0, 0),
         "skin frame did not paint its clipped hard shadow");
      Assert
        (Flyology_TUI.Surfaces.Width (Intrinsic) = 7
         and then Flyology_TUI.Surfaces.Height (Intrinsic) = 4
         and then Glyph (Intrinsic, 1, 1) = "b"
         and then Glyph (Intrinsic, 4, 1) = "y",
         "intrinsic skin frame consumed content space for its shadow");
      Assert
        (Oversized.Element (4, 1).Appearance.Background =
           Turbo.Panel.Shadow.Background
         and then Oversized.Element (1, 3).Appearance.Background =
           Turbo.Panel.Shadow.Background,
         "oversized frame content overwrote the reserved hard shadow");
   end Test_Frame_Chrome;

   procedure Test_Color_Inheritance is
      Parent : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Skins.Turbo_Vision_Skin.Palette.Content;
      Explicit : constant Flyology_TUI.Styles.Style :=
        (Foreground => Flyology_TUI.Colors.Basic
           (Flyology_TUI.Colors.Yellow),
         Bold => True,
         others => <>);
      Child : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (2, 1);
      Result : Flyology_TUI.Surfaces.Surface;
   begin
      Child.Put (0, 0, "a", Explicit);
      Child.Put (1, 0, "b");
      Result := Flyology_TUI.Surfaces.Inherit_Colors (Child, Parent);
      Assert
        (Result.Element (0, 0).Appearance.Foreground = Explicit.Foreground
         and then Result.Element (0, 0).Appearance.Background =
           Parent.Background
         and then Result.Element (0, 0).Appearance.Bold
         and then Result.Element (1, 0).Appearance.Foreground =
           Parent.Foreground
         and then Result.Element (1, 0).Appearance.Background =
           Parent.Background,
         "surface color inheritance overwrote explicit child styling");
   end Test_Color_Inheritance;

   procedure Test_Tab_Chrome is
      Item : constant Tabs.Model := Tabs.Create ([First_Tab, Second_Tab]);
      Layout : constant Tabs.Presentation := Item.Present
        (12, Flyology_TUI.Skins.Turbo_Vision_Skin, True);
      Frame : constant Flyology_TUI.Surfaces.Surface := Tabs.Frame (Layout);
   begin
      Assert
        (Glyph (Frame, 0, 0) =
           [1 => Wide_Wide_Character'Val (16#00AB#)]
         and then Glyph (Frame, 4, 0) =
           [1 => Wide_Wide_Character'Val (16#00BB#)],
         "skin tab active cue was not rendered");
      Assert
        (Tabs.Tab_Region (Layout, First_Tab) = (0, 0, 5, 1),
         "skin tab cue changed immutable hit geometry");
   end Test_Tab_Chrome;

   procedure Test_Window_Chrome is
      Item : constant Flyology_TUI.Components.Windows.Model :=
        Flyology_TUI.Components.Windows.Create (1, 1, 6, 4);
      Workspace : constant Flyology_TUI.Geometry.Rectangle := (0, 0, 12, 8);
      Frame : constant Flyology_TUI.Surfaces.Surface := Item.Render
        ("Demo", Flyology_TUI.Surfaces.From_Text ("body"), Workspace,
         Flyology_TUI.Skins.Turbo_Vision_Skin);
   begin
      Assert
        (Glyph (Frame, 1, 1) =
           [1 => Wide_Wide_Character'Val (16#2554#)]
         and then Glyph (Frame, 5, 1) =
           [1 => Wide_Wide_Character'Val (16#25A0#)],
         "skin window frame or close mark was not rendered");
      Assert
        (Frame.Element (7, 2).Appearance.Background =
           Flyology_TUI.Colors.True_Color (0, 0, 0)
         and then Frame.Element (2, 5).Appearance.Background =
           Flyology_TUI.Colors.True_Color (0, 0, 0),
         "skin window hard shadow was not rendered behind the frame");
   end Test_Window_Chrome;
begin
   Test_Presets;
   Test_Frame_Chrome;
   Test_Color_Inheritance;
   Test_Tab_Chrome;
   Test_Window_Chrome;
   Ada.Text_IO.Put_Line ("skin tests passed");
end Skin_Tests;
