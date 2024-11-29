reading_file=open("mumps_io.h","r")
new_file_content=""
for line in reading_file:
    stripped_line=line.strip()
    new_line=stripped_line.replace('DUMP_RHSBINARY_C','DUMPRHSBINARY_C').replace('DUMP_MATBINARY_C', 'DUMPMATBINARY_C')
    new_file_content += new_line +'\n'
reading_file.close()
writing_file=open("mumps_io.h","w")
writing_file.write(new_file_content)
writing_file.close()
