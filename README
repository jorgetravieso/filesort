  Quicksort File Sorter  

  Contacts  
  --------
  Group Members:  
  Jorge Travieso 	jtrav029@fiu.edu  <http://jorgetravieso.com>  
  Guido Ruiz		gruiz044@fiu.edu  
  
  Professor: 		Ming Zhao, Phd <zhaom@cis.fiu.edu>  
  Course:		    CDA 4101 Structured Comp. Org.  http://visa.cs.fiu.edu/ming/courses/cda4101-spring2014/  
  Date:			    04/28/2014  

  
  What is it?  
  -----------
  TYPE: Intel x86 NASM Assembly Program
  TARGET OS: Any GNU Linux 32 bit distribution
  
  OVERVIEW:  
  This program is intended to sort files made up of tab-separated strings. Quicksort algorithm is used, and an 
  average running time of 4 seconds is the time it takes for this program to process one million 
  strings, including sorting (0.7 seconds), and printing to a file (3.3 seconds). An output file 
  is generated in the direcory of this program, containing the resulting strings in a sorted fashion. 
  Arguments containing the file name is needed for the program to run successfully, as well as the 
  name of the output file desired. Use a space to separate the two. Please visit the NASM website 
  for more information on NASM, and the GNU website for help with compiling or executing.

  FEATURES:  
  A maximum of 8 million strings can be sorted. The strings can be of infinite size long. This
  program can also substitute an EOF character if the file does not have one to stop searching
  for new strings. An average of 4 seconds was observed to complete the procedure on a natural
  Ubuntu machine running on Intel Core i3. However, this time decreased to 2.5 seconds on a 
  virtual machine running Intel Core i7. The speed of this program depends on how fast the memory 
  and processor is on the machine it is running on, and the average case for the algorithm used to 
  sort the strings (QuickSort) is O(nlogn). Worst case is O(n^2).


  Installation  
  ------------

  Compile using NASM Assembler <http://www.nasm.us/> in 32-bit GNU/Linux.  <https://www.gnu.org/>  
  
  Compile:        nasm -f elf filesort.asm  
  Link:		        ld -o filesort filesort.o  
  Execute:	     ./filesort <input_file> <output_file>  