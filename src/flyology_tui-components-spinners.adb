package body Flyology_TUI.Components.Spinners is

   function Frame_Count (Kind : Spinner_Style) return Positive is
     (case Kind is
         when Dots  => 10,
         when Line  => 4,
         when Pulse => 4);

   function Glyph (Kind : Spinner_Style; Position : Natural)
      return Wide_Wide_String
   is
   begin
      case Kind is
         when Dots =>
            case Position mod 10 is
               when 0 => return "⠋";
               when 1 => return "⠙";
               when 2 => return "⠹";
               when 3 => return "⠸";
               when 4 => return "⠼";
               when 5 => return "⠴";
               when 6 => return "⠦";
               when 7 => return "⠧";
               when 8 => return "⠇";
               when others => return "⠏";
            end case;
         when Line =>
            case Position mod 4 is
               when 0 => return "│";
               when 1 => return "/";
               when 2 => return "─";
               when others => return "\\";
            end case;
         when Pulse =>
            case Position mod 4 is
               when 0 => return "░";
               when 1 => return "▒";
               when 2 => return "▓";
               when others => return "▒";
            end case;
      end case;
   end Glyph;

   function Create (Kind : Spinner_Style := Dots) return Model is
     (Kind => Kind, others => <>);

   procedure Tick (Item : in out Model) is
   begin
      if Item.Active then
         Item.Position := (Item.Position + 1) mod Frame_Count (Item.Kind);
      end if;
   end Tick;

   procedure Start (Item : in out Model) is
   begin
      Item.Active := True;
   end Start;

   procedure Stop (Item : in out Model) is
   begin
      Item.Active := False;
   end Stop;

   function Running (Item : Model) return Boolean is (Item.Active);

   function Render
     (Item       : Model;
      Appearance : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface
   is (Flyology_TUI.Surfaces.From_Text
         (Glyph (Item.Kind, Item.Position), Appearance));

end Flyology_TUI.Components.Spinners;
