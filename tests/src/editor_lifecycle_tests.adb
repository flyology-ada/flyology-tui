with Ada.Text_IO;
with Flyology_TUI.Components.Syntax_Editors;
with Flyology_TUI.Components.Text_Areas;

procedure Editor_Lifecycle_Tests is
   type Token is (Word);
   type State is (Normal);

   procedure Next_Token
     (Line        : Wide_Wide_String;
      Initial     : State;
      From        : Natural;
      Kind        : out Token;
      First, Last : out Natural;
      Final       : out State;
      Has_Token   : out Boolean)
   is
      pragma Unreferenced (Line, From);
   begin
      Kind := Word;
      First := 0;
      Last := 0;
      Final := Initial;
      Has_Token := False;
   end Next_Token;

   package Editors is new Flyology_TUI.Components.Syntax_Editors
     (Token_Kind              => Token,
      Lexer_State             => State,
      Initial_State           => Normal,
      Maximum_Tokens_Per_Line => 8,
      Next_Token              => Next_Token);

   type Application_Model is limited record
      Text : Flyology_TUI.Components.Text_Areas.Model
        (2_048, 128, 32, 8_192) :=
        Flyology_TUI.Components.Text_Areas.Create
          (2_048, 128, 32, 8_192, 28, 13, "notes");
      Syntax : Editors.Model (4_096, 256, 32, 12_288) :=
        Editors.Create
          (4_096, 256, 32, 12_288, 28, 13, "Ada source");
   end record;
begin
   --  Exercise the same component-default-expression and finalization path as
   --  an application model. Optimization previously exposed aliased owned
   --  strings in the bounded undo arrays when each host left scope.
   for Iteration in 1 .. 32 loop
      declare
         Item : Application_Model;
         Success : Boolean;
      begin
         Item.Text.Try_Set_Text
           ("bounded notes" & Wide_Wide_Character'Val (10)
            & Wide_Wide_Character'Val (16#03BB#),
            Success);
         if not Success then
            raise Program_Error with "text-area lifecycle seed rejected";
         end if;
         Item.Text.Set_Cursor_Offset (Iteration mod 13);
         Item.Syntax.Try_Set_Text
           ("procedure Hello is" & Wide_Wide_Character'Val (10)
            & "begin null; end Hello;",
            Success);
         if not Success then
            raise Program_Error with "syntax lifecycle seed rejected";
         end if;
         Item.Syntax.Advance_Highlighting (2);
         if Item.Text.Width /= 28
           or else Item.Syntax.Width /= 28
         then
            raise Program_Error with "editor lifecycle model corrupted";
         end if;
      end;
   end loop;
   Ada.Text_IO.Put_Line ("editor lifecycle tests passed");
end Editor_Lifecycle_Tests;
