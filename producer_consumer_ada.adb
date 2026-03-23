with Ada.Text_IO;         use Ada.Text_IO;
with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Strings;         use Ada.Strings;
with Ada.Strings.Fixed;   use Ada.Strings.Fixed;

procedure Producer_Consumer_Ada is

   Capacity       : Positive;
   Total_Items    : Natural;
   Producer_Count : Positive;
   Consumer_Count : Positive;

   Poison_Pill : constant Integer := -1;

   function Img (N : Integer) return String is
   begin
      return Trim (Integer'Image (N), Both);
   end Img;

begin
   Put ("Enter storage capacity: ");
   Get (Capacity);

   Put ("Enter total number of items: ");
   Get (Total_Items);

   Put ("Enter number of producers: ");
   Get (Producer_Count);

   Put ("Enter number of consumers: ");
   Get (Consumer_Count);

   declare
      type Buffer_Array is array (Positive range <>) of Integer;

      protected type Storage (Max_Size : Positive) is
         entry Put_Item (Item : Integer; Producer_Id : Integer);
         entry Take_Item (Item : out Integer; Consumer_Id : Integer);
      private
         Buffer : Buffer_Array (1 .. Max_Size) := (others => 0);
         Head   : Positive := 1;
         Tail   : Positive := 1;
         Count  : Natural  := 0;
      end Storage;

      protected body Storage is
         entry Put_Item (Item : Integer; Producer_Id : Integer)
           when Count < Max_Size
         is
         begin
            Buffer (Tail) := Item;

            if Tail = Max_Size then
               Tail := 1;
            else
               Tail := Tail + 1;
            end if;

            Count := Count + 1;

            Put_Line
              ("Producer-" & Img (Producer_Id)
               & " produced: " & Img (Item)
               & " | buffer size = " & Img (Integer (Count)));
         end Put_Item;

         entry Take_Item (Item : out Integer; Consumer_Id : Integer)
           when Count > 0
         is
         begin
            Item := Buffer (Head);

            if Head = Max_Size then
               Head := 1;
            else
               Head := Head + 1;
            end if;

            Count := Count - 1;

            Put_Line
              ("Consumer-" & Img (Consumer_Id)
               & " consumed: " & Img (Item)
               & " | buffer size = " & Img (Integer (Count)));
         end Take_Item;
      end Storage;

      Shared_Storage : Storage (Capacity);

      protected Counter is
         procedure Get_Next (Item : out Integer; Done : out Boolean);
      private
         Next_Value : Natural := 1;
      end Counter;

      protected body Counter is
         procedure Get_Next (Item : out Integer; Done : out Boolean) is
         begin
            if Next_Value > Total_Items then
               Done := True;
               Item := 0;
            else
               Item := Integer (Next_Value);
               Next_Value := Next_Value + 1;
               Done := False;
            end if;
         end Get_Next;
      end Counter;

      protected Producer_Status is
         procedure Mark_Done;
         entry Wait_All_Done;
      private
         Remaining : Natural := Natural (Producer_Count);
      end Producer_Status;

      protected body Producer_Status is
         procedure Mark_Done is
         begin
            if Remaining > 0 then
               Remaining := Remaining - 1;
            end if;
         end Mark_Done;

         entry Wait_All_Done when Remaining = 0 is
         begin
            null;
         end Wait_All_Done;
      end Producer_Status;

      task type Producer is
         entry Start (Id : Positive);
      end Producer;

      task type Consumer is
         entry Start (Id : Positive);
      end Consumer;

      task body Producer is
         My_Id : Positive := 1;
         Item  : Integer;
         Done  : Boolean;
      begin
         accept Start (Id : Positive) do
            My_Id := Id;
         end Start;

         loop
            Counter.Get_Next (Item, Done);
            exit when Done;

            Shared_Storage.Put_Item (Item, Integer (My_Id));
            delay 0.10;
         end loop;

         Put_Line ("Producer-" & Img (Integer (My_Id)) & " finished.");
         Producer_Status.Mark_Done;
      end Producer;

      task body Consumer is
         My_Id : Positive := 1;
         Item  : Integer;
      begin
         accept Start (Id : Positive) do
            My_Id := Id;
         end Start;

         loop
            Shared_Storage.Take_Item (Item, Integer (My_Id));
            exit when Item = Poison_Pill;
            delay 0.15;
         end loop;

         Put_Line ("Consumer-" & Img (Integer (My_Id)) & " finished.");
      end Consumer;

      Producers : array (1 .. Producer_Count) of Producer;
      Consumers : array (1 .. Consumer_Count) of Consumer;

   begin
      for I in Consumers'Range loop
         Consumers (I).Start (I);
      end loop;

      for I in Producers'Range loop
         Producers (I).Start (I);
      end loop;

      Producer_Status.Wait_All_Done;

      for I in 1 .. Consumer_Count loop
         Shared_Storage.Put_Item (Poison_Pill, 0);
      end loop;
   end;

   Put_Line ("Program finished successfully.");
end Producer_Consumer_Ada;