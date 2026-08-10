with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Color_Profiles;
with Flyology_TUI.Colors;
with Flyology_TUI.Components.Gradients;
with Flyology_TUI.Renderers;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Views;

procedure Gradient_Tests is
   package Gradients renames Flyology_TUI.Components.Gradients;
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Colors.Color;
   use type Flyology_TUI.Colors.Color_Kind;
   use type Gradients.Stop;
   use type Flyology_TUI.Styles.Style;

   ESC : constant Character := Ada.Characters.Latin_1.ESC;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function RGB
     (Red, Green, Blue : Flyology_TUI.Colors.Channel)
      return Gradients.RGB_Color is
     (Red => Red, Green => Green, Blue => Blue);

   procedure Assert_RGB
     (Value : Gradients.RGB_Color;
      Red, Green, Blue : Flyology_TUI.Colors.Channel;
      Message : String) is
   begin
      Assert
        (Value.Red = Red and then Value.Green = Green
         and then Value.Blue = Blue,
         Message);
   end Assert_RGB;

   procedure Assert_RGB_Style
     (Value : Flyology_TUI.Colors.Color;
      Red, Green, Blue : Flyology_TUI.Colors.Channel;
      Message : String) is
   begin
      Assert
        (Value.Kind = Flyology_TUI.Colors.RGB
         and then Value.Red_Value = Red
         and then Value.Green_Value = Green
         and then Value.Blue_Value = Blue,
         Message);
   end Assert_RGB_Style;

   procedure Test_Stops_And_Interpolation is
      Item : Gradients.Model := Gradients.Create (3);
      Success : Boolean;
      Original : Gradients.Stop;
      Empty : constant Gradients.Stop_Array (1 .. 0) := [];
   begin
      Assert
        (Item.Stop_Count = 1 and then Item.Stop_At (1).Offset = 0,
         "create did not establish a solid bounded gradient");
      Item.Try_Set_Stops
        ([10 => (0, RGB (0, 0, 0)),
          11 => (500_000, RGB (255, 0, 0)),
          12 => (Gradients.Stop_Scale, RGB (255, 255, 255))],
         Success);
      Assert (Success and then Item.Stop_Count = 3,
              "ordered stops were rejected");
      Assert_RGB (Item.Sample (0), 0, 0, 0, "first endpoint drifted");
      Assert_RGB
        (Item.Sample (250_000), 128, 0, 0,
         "sRGB midpoint did not round an exact half upward");
      Assert_RGB
        (Item.Sample (500_000), 255, 0, 0,
         "interior stop was not exact");
      Assert_RGB
        (Item.Sample (Gradients.Stop_Scale), 255, 255, 255,
         "last endpoint drifted");

      Original := Item.Stop_At (2);
      Item.Try_Set_Stops
        ([(0, RGB (1, 2, 3)), (0, RGB (4, 5, 6))], Success);
      Assert
        (not Success and then Item.Stop_Count = 3
         and then Item.Stop_At (2) = Original,
         "duplicate stop rejection was not atomic");
      Item.Try_Set_Stops
        ([(800_000, RGB (1, 2, 3)), (700_000, RGB (4, 5, 6))],
         Success);
      Assert
        (not Success and then Item.Stop_At (2) = Original,
         "descending stop rejection was not atomic");
      Item.Try_Set_Stops
        ([(0, RGB (0, 0, 0)), (1, RGB (1, 1, 1)),
          (2, RGB (2, 2, 2)), (3, RGB (3, 3, 3))],
         Success);
      Assert
        (not Success and then Item.Stop_Count = 3,
         "stop capacity rejection was not atomic");
      Item.Try_Set_Stops (Empty, Success);
      Assert
        (not Success and then Item.Stop_Count = 3,
         "empty stop rejection was not atomic");

      Item.Try_Set_Stops
        ([(0, RGB (0, 0, 0)),
          (Gradients.Stop_Scale, RGB (255, 255, 255))], Success);
      Item.Set_Interpolation (Gradients.Linear_Light);
      Assert_RGB
        (Item.Sample (500_000), 188, 188, 188,
         "linear-light midpoint did not use the sRGB transfer function");
      Item.Set_Solid (RGB (7, 8, 9));
      Assert_RGB
        (Item.Sample (Gradients.Stop_Scale), 7, 8, 9,
         "solid gradient depended on sample position");
   end Test_Stops_And_Interpolation;

   procedure Test_Surface_Application is
      Base : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Item : Gradients.Model := Gradients.Create (2);
      Success : Boolean;
      Surface : Flyology_TUI.Surfaces.Surface;
   begin
      Base.Bold := True;
      Base.Italic := True;
      Base.Background :=
        Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Blue);
      Item.Try_Set_Stops
        ([(0, RGB (0, 0, 0)),
          (Gradients.Stop_Scale, RGB (255, 255, 255))], Success);
      Surface := Flyology_TUI.Surfaces.Create (3, 2, Base);
      Item.Apply (Surface, (0, 0, 3, 2));
      Assert_RGB_Style
        (Surface.Element (0, 0).Appearance.Foreground, 0, 0, 0,
         "horizontal gradient lost its first endpoint");
      Assert_RGB_Style
        (Surface.Element (1, 0).Appearance.Foreground, 128, 128, 128,
         "horizontal gradient midpoint was wrong");
      Assert_RGB_Style
        (Surface.Element (2, 1).Appearance.Foreground, 255, 255, 255,
         "horizontal gradient lost its last endpoint");
      Assert
        (Surface.Element (1, 0).Appearance.Bold
         and then Surface.Element (1, 0).Appearance.Italic
         and then Surface.Element (1, 0).Appearance.Background =
           Base.Background,
         "foreground application discarded external style fields");

      Item.Set_Direction (Gradients.Vertical);
      Item.Set_Application (Gradients.Apply_Background);
      Surface := Flyology_TUI.Surfaces.Create (2, 2, Base);
      Item.Apply (Surface, (0, 0, 2, 2));
      Assert_RGB_Style
        (Surface.Element (0, 0).Appearance.Background, 0, 0, 0,
         "vertical background start was wrong");
      Assert_RGB_Style
        (Surface.Element (1, 1).Appearance.Background, 255, 255, 255,
         "vertical background end was wrong");
      Assert
        (Surface.Element (1, 1).Appearance.Foreground = Base.Foreground
         and then Surface.Element (1, 1).Appearance.Bold,
         "background application discarded foreground or attributes");

      Item.Set_Direction (Gradients.Horizontal);
      Item.Set_Application (Gradients.Apply_Foreground);
      Surface := Flyology_TUI.Surfaces.Create (1, 1, Base);
      Item.Apply (Surface, (0, 0, 1, 1));
      Assert_RGB_Style
        (Surface.Element (0, 0).Appearance.Foreground, 0, 0, 0,
         "one-cell gradient did not choose its first endpoint");

      Item.Set_Application (Gradients.Apply_Both);
      Item.Set_Solid (RGB (12, 34, 56));
      Surface := Flyology_TUI.Surfaces.Create (1, 1, Base);
      Item.Apply (Surface, (0, 0, 1, 1));
      Assert_RGB_Style
        (Surface.Element (0, 0).Appearance.Foreground, 12, 34, 56,
         "both application missed foreground");
      Assert_RGB_Style
        (Surface.Element (0, 0).Appearance.Background, 12, 34, 56,
         "both application missed background");
   end Test_Surface_Application;

   procedure Test_Clipping_And_Wide_Glyphs is
      Item : Gradients.Model := Gradients.Create (2);
      Success : Boolean;
      Base : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Surface : Flyology_TUI.Surfaces.Surface;
      Wide : constant Wide_Wide_String :=
        [1 => Wide_Wide_Character'Val (16#754C#)];
   begin
      Item.Try_Set_Stops
        ([(0, RGB (0, 0, 0)),
          (Gradients.Stop_Scale, RGB (255, 255, 255))], Success);
      Surface := Flyology_TUI.Surfaces.Create (4, 1, Base);
      Item.Apply (Surface, (-1, 0, 3, 1));
      Assert_RGB_Style
        (Surface.Element (0, 0).Appearance.Foreground, 128, 128, 128,
         "negative clipped origin changed gradient coordinates");
      Assert_RGB_Style
        (Surface.Element (1, 0).Appearance.Foreground, 255, 255, 255,
         "clipped region endpoint was wrong");
      Assert
        (Surface.Element (2, 0).Appearance = Base,
         "clipped region escaped its requested bounds");

      Surface := Flyology_TUI.Surfaces.Create (2, 1, Base);
      Item.Apply (Surface, (0, 0, 0, 1));
      Item.Apply (Surface, (Integer'Last, Integer'Last,
                           Natural'Last, Natural'Last));
      Assert
        (Surface.Element (0, 0).Appearance = Base,
         "zero or overflow-adjacent region changed the surface");
      Item.Apply
        (Surface, (Integer'First, 0, Natural'Last, Natural'Last));
      Assert
        (Surface.Element (0, 0).Appearance = Base,
         "large signed clipped region overflowed into the surface");
      Surface := Flyology_TUI.Surfaces.Create (0, 0, Base);
      Item.Apply (Surface, (-10, -10, Natural'Last, Natural'Last));
      Assert
        (Surface.Width = 0 and then Surface.Height = 0,
         "empty surface application changed its geometry");

      Surface := Flyology_TUI.Surfaces.From_Text (Wide & "x", Base);
      Item.Set_Solid (RGB (90, 80, 70));
      Item.Apply (Surface, (1, 0, 1, 1));
      Assert
        (Surface.Element (0, 0).Appearance = Base
         and then Surface.Element (1, 0).Continuation
         and then Surface.Element (1, 0).Appearance = Base,
         "continuation-only clipping split a wide glyph");
      Item.Apply (Surface, (0, 0, 2, 1));
      Assert_RGB_Style
        (Surface.Element (0, 0).Appearance.Foreground, 90, 80, 70,
         "complete wide glyph was not recolored");
      Assert
        (Surface.Element (1, 0).Continuation
         and then Surface.Element (1, 0).Appearance =
           Surface.Element (0, 0).Appearance
         and then Text.To_Wide_Wide_String
           (Surface.Element (0, 0).Glyph) = Wide,
         "wide glyph continuation or cluster was corrupted");
   end Test_Clipping_And_Wide_Glyphs;

   procedure Test_Heatmap is
      Item : Gradients.Model := Gradients.Create (2);
      Success : Boolean;
   begin
      Item.Try_Set_Stops
        ([(0, RGB (0, 0, 255)),
          (Gradients.Stop_Scale, RGB (255, 0, 0))], Success);
      Assert_RGB
        (Item.Heatmap (-1.0, 0.0, 100.0), 0, 0, 255,
         "heatmap did not clamp below its domain");
      Assert_RGB
        (Item.Heatmap (50.0, 0.0, 100.0), 128, 0, 128,
         "heatmap midpoint was wrong");
      Assert_RGB
        (Item.Heatmap (101.0, 0.0, 100.0), 255, 0, 0,
         "heatmap did not clamp above its domain");
   end Test_Heatmap;

   procedure Test_Renderer_Profiles is
      Item : constant Gradients.Model := Gradients.Create
        (1, RGB (255, 0, 0), Application => Gradients.Apply_Foreground);
      Base : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Surface : Flyology_TUI.Surfaces.Surface;

      procedure Verify
        (Profile : Flyology_TUI.Color_Profiles.Profile;
         Expected : String;
         Message : String)
      is
         Renderer : Flyology_TUI.Renderers.Renderer;
         Output : Ada.Strings.Unbounded.Unbounded_String;
      begin
         Renderer.Set_Color_Profile (Profile);
         Renderer.Render
           (Flyology_TUI.Views.From_Surface (Surface), Output);
         Assert
           (Ada.Strings.Fixed.Index
              (Ada.Strings.Unbounded.To_String (Output), Expected) /= 0,
            Message);
      end Verify;
   begin
      Base.Bold := True;
      Surface := Flyology_TUI.Surfaces.Create (1, 1, Base);
      Item.Apply (Surface, (0, 0, 1, 1));
      Verify
        (Flyology_TUI.Color_Profiles.Truecolor,
         ESC & "[38;2;255;0;0m", "truecolor renderer lost gradient RGB");
      Verify
        (Flyology_TUI.Color_Profiles.ANSI_256,
         ESC & "[38;5;9m", "ANSI-256 renderer did not degrade gradient RGB");
      Verify
        (Flyology_TUI.Color_Profiles.ANSI_16,
         ESC & "[91m", "ANSI-16 renderer did not degrade gradient RGB");
      Verify
        (Flyology_TUI.Color_Profiles.Monochrome,
         ESC & "[39m", "monochrome renderer did not remove gradient color");
   end Test_Renderer_Profiles;

begin
   Test_Stops_And_Interpolation;
   Test_Surface_Application;
   Test_Clipping_And_Wide_Glyphs;
   Test_Heatmap;
   Test_Renderer_Profiles;
   Ada.Text_IO.Put_Line ("gradient tests passed");
end Gradient_Tests;
