with Ada.Environment_Variables;
with Ada.Strings.Unbounded;

package body Flyology_TUI.Backends.POSIX is
   use type Interfaces.C.long;
   use type System.Address;

   Input_FD  : constant Interfaces.C.int := 0;
   Output_FD : constant Interfaces.C.int := 1;
   Poll_Interval_Milliseconds : constant Interfaces.C.int := 50;

   function Raw_Enable (FD : Interfaces.C.int) return System.Address
     with Import, Convention => C, External_Name => "flyology_tui_raw_enable";

   function Raw_Restore
     (FD    : Interfaces.C.int;
      State : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "flyology_tui_raw_restore";

   function Terminal_Size
     (FD     : Interfaces.C.int;
      Width  : access Interfaces.C.unsigned;
      Height : access Interfaces.C.unsigned) return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "flyology_tui_terminal_size";

   function Wake_Open
     (Read_FD, Write_FD : access Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "flyology_tui_wake_open";

   function Poll
     (Input_FD, Wake_FD, Timeout_MS : Interfaces.C.int)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "flyology_tui_poll";

   function Wake_Signal (FD : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "flyology_tui_wake_signal";

   procedure Wake_Drain (FD : Interfaces.C.int)
     with Import, Convention => C,
          External_Name => "flyology_tui_wake_drain";

   procedure FD_Close (FD : Interfaces.C.int)
     with Import, Convention => C, External_Name => "flyology_tui_fd_close";

   function C_Read
     (FD     : Interfaces.C.int;
      Buffer : System.Address;
      Count  : Interfaces.C.size_t) return Interfaces.C.long
     with Import, Convention => C, External_Name => "read";

   function C_Write
     (FD     : Interfaces.C.int;
      Buffer : System.Address;
      Count  : Interfaces.C.size_t) return Interfaces.C.long
     with Import, Convention => C, External_Name => "write";

   procedure Write_All (Value : String) is
      Offset : Natural := 0;
   begin
      while Offset < Value'Length loop
         declare
            Result : constant Interfaces.C.long :=
              C_Write
                (Output_FD,
                 Value (Value'First + Offset)'Address,
                 Interfaces.C.size_t (Value'Length - Offset));
         begin
            if Result <= 0 then
               raise Backend_Error with "terminal write failed";
            end if;
            Offset := Offset + Natural (Result);
         end;
      end loop;
   end Write_All;

   procedure Read_Size
     (Width, Height : out Natural;
      Valid         : out Boolean)
   is
      C_Width, C_Height : aliased Interfaces.C.unsigned := 0;
   begin
      Valid := Terminal_Size
        (Output_FD, C_Width'Access, C_Height'Access) = 0;
      Width := Natural (C_Width);
      Height := Natural (C_Height);
   end Read_Size;

   function Environment_Value (Name : String) return String is
     (if Ada.Environment_Variables.Exists (Name)
      then Ada.Environment_Variables.Value (Name)
      else "");

   function Detected_Color_Profile
     return Flyology_TUI.Color_Profiles.Profile
   is
     (Flyology_TUI.Color_Profiles.Detect
        (NO_Color_Present => Ada.Environment_Variables.Exists ("NO_COLOR"),
         NO_Color_Value   => Environment_Value ("NO_COLOR"),
         Color_Term       => Environment_Value ("COLORTERM"),
         Term             => Environment_Value ("TERM")));

   overriding procedure Open (Item : in out POSIX_Backend) is
      Width, Height : Natural;
      Valid : Boolean;
   begin
      if Item.Is_Open then
         return;
      end if;
      Item.Size_Available := False;
      Item.Raw_State := Raw_Enable (Input_FD);
      if Item.Raw_State = System.Null_Address then
         raise Backend_Error with
           "standard input is not an available terminal";
      end if;
      if Wake_Open (Item.Wake_Read'Access, Item.Wake_Write'Access) /= 0 then
         declare
            Ignored : constant Interfaces.C.int :=
              Raw_Restore (Input_FD, Item.Raw_State);
         begin
            pragma Unreferenced (Ignored);
         end;
         Item.Raw_State := System.Null_Address;
         raise Backend_Error with "could not create terminal wake channel";
      end if;
      Flyology_TUI.Input.Initialize (Item.Input_Parser);
      Item.Effective_Color :=
        Flyology_TUI.Color_Profiles.Resolve
          (Item.Requested_Color, Detected_Color_Profile);
      Flyology_TUI.Renderers.Set_Color_Profile
        (Item.Frame_Renderer, Item.Effective_Color);
      Read_Size (Width, Height, Valid);
      if Valid then
         Item.Last_Width := Width;
         Item.Last_Height := Height;
      end if;
      Item.Size_Available := Valid;
      Item.Is_Open := True;
   end Open;

   overriding procedure Current_Size
     (Item      : POSIX_Backend;
      Width     : in out Natural;
      Height    : in out Natural;
      Available : in out Boolean) is
   begin
      Width := Item.Last_Width;
      Height := Item.Last_Height;
      Available := Item.Is_Open and then Item.Size_Available;
   end Current_Size;

   overriding procedure Close (Item : in out POSIX_Backend) is
      Output : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Item.Is_Open and then Item.Raw_State = System.Null_Address then
         return;
      end if;

      Flyology_TUI.Renderers.Reset (Item.Frame_Renderer, Output);
      begin
         Write_All (Ada.Strings.Unbounded.To_String (Output));
      exception
         when others => null;
      end;
      if Item.Raw_State /= System.Null_Address then
         declare
            Ignored : constant Interfaces.C.int :=
              Raw_Restore (Input_FD, Item.Raw_State);
         begin
            pragma Unreferenced (Ignored);
         end;
         Item.Raw_State := System.Null_Address;
      end if;
      FD_Close (Item.Wake_Read);
      FD_Close (Item.Wake_Write);
      Item.Wake_Read := -1;
      Item.Wake_Write := -1;
      Item.Is_Open := False;
      Item.Size_Available := False;
   end Close;

   overriding procedure Next_Event
     (Item   : in out POSIX_Backend;
      Event  : out Flyology_TUI.Events.Terminal_Event;
      Status : out Input_Status)
   is
      Available : Boolean;
      Width, Height : Natural;
      Valid : Boolean;
      Ready : Interfaces.C.int;
      Buffer : aliased String (1 .. 4_096);
      Count : Interfaces.C.long;
   begin
      if not Item.Is_Open then
         raise Backend_Error with "backend is not open";
      end if;
      loop
         Flyology_TUI.Input.Next_Event
           (Item.Input_Parser, Event, Available);
         if Available then
            Status := Event_Available;
            return;
         end if;

         Read_Size (Width, Height, Valid);
         if Valid
           and then
             (not Item.Size_Available
              or else Width /= Item.Last_Width
              or else Height /= Item.Last_Height)
         then
            Item.Last_Width := Width;
            Item.Last_Height := Height;
            Item.Size_Available := True;
            Event := Flyology_TUI.Events.Resized (Width, Height);
            Status := Event_Available;
            return;
         end if;

         Ready := Poll
           (Input_FD, Item.Wake_Read, Poll_Interval_Milliseconds);
         if Ready < 0 then
            raise Backend_Error with "terminal wait failed";
         elsif (Ready / 2) mod 2 = 1 then
            Wake_Drain (Item.Wake_Read);
            Event := (Kind => Flyology_TUI.Events.Interrupt);
            Status := Interrupted;
            return;
         elsif Ready mod 2 = 1 then
            Count := C_Read
              (Input_FD, Buffer'Address, Interfaces.C.size_t (Buffer'Length));
            if Count = 0 then
               Event := (Kind => Flyology_TUI.Events.Interrupt);
               Status := End_Of_Input;
               return;
            elsif Count < 0 then
               raise Backend_Error with "terminal read failed";
            else
               Flyology_TUI.Input.Feed
                 (Item.Input_Parser, Buffer (1 .. Natural (Count)));
            end if;
         else
            Flyology_TUI.Input.Flush_Escape (Item.Input_Parser);
         end if;
      end loop;
   end Next_Event;

   overriding procedure Render
     (Item : in out POSIX_Backend;
      View : Flyology_TUI.Views.View)
   is
      Output : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Item.Is_Open then
         raise Backend_Error with "backend is not open";
      end if;
      Flyology_TUI.Renderers.Render (Item.Frame_Renderer, View, Output);
      Write_All (Ada.Strings.Unbounded.To_String (Output));
   end Render;

   overriding procedure Interrupt (Item : in out POSIX_Backend) is
      Result : Interfaces.C.int;
   begin
      if Item.Is_Open then
         Result := Wake_Signal (Item.Wake_Write);
         if Result /= 0 then
            raise Backend_Error with "terminal wake failed";
         end if;
      end if;
   end Interrupt;

   procedure Set_Color_Policy
     (Item   : in out POSIX_Backend;
      Policy : Flyology_TUI.Color_Profiles.Policy)
   is
   begin
      if Item.Is_Open then
         raise Backend_Error with
           "color policy must be configured before opening the backend";
      end if;
      Item.Requested_Color := Policy;
   end Set_Color_Policy;

   function Color_Policy
     (Item : POSIX_Backend) return Flyology_TUI.Color_Profiles.Policy
   is (Item.Requested_Color);

   function Color_Profile
     (Item : POSIX_Backend) return Flyology_TUI.Color_Profiles.Profile
   is
   begin
      if not Item.Is_Open then
         raise Backend_Error with
           "color profile is unavailable while the backend is closed";
      end if;
      return Item.Effective_Color;
   end Color_Profile;

   overriding procedure Finalize (Item : in out POSIX_Backend) is
   begin
      Close (Item);
   end Finalize;

end Flyology_TUI.Backends.POSIX;
