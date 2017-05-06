/* 
 * Copyright (C) 2012-2014 Chris McClelland
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *  
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
//#include <errno.h>
//#include <makestuff.h>
#include <libfpgalink.h>
//#include <libbuffer.h>
//#include <liberror.h>
//#include <libdump.h>
//#include <argtable2.h>
//#include <readline/readline.h>
//#include <readline/history.h>
#ifdef WIN32
#include <Windows.h>
#else
#include <sys/time.h>
#endif
typedef enum {
	FLP_SUCCESS,
	FLP_LIBERR,
	FLP_BAD_HEX,
	FLP_CHAN_RANGE,
	FLP_CONDUIT_RANGE,
	FLP_ILL_CHAR,
	FLP_UNTERM_STRING,
	FLP_NO_MEMORY,
	FLP_EMPTY_STRING,
	FLP_ODD_DIGITS,
	FLP_CANNOT_LOAD,
	FLP_CANNOT_SAVE,
	FLP_ARGS
} ReturnCode;
uint8 min(uint8 a,uint8 b){
	if(a < b) return a;
	return b;
}
void decrypt(uint8 *datafromboard ){

	uint32 v1 = datafromboard[3] | (datafromboard[2] << 8) | (datafromboard[1] << 16) | (datafromboard[0] << 24);
	uint32 v0 = datafromboard[7] | (datafromboard[6] << 8) | (datafromboard[5] << 16) | (datafromboard[4] << 24);
	uint32 delta = 0x9e3779b9,sum = 0xC6EF3720;                     /* a key schedule constant */
    //take the values of key
    uint32 k0=0x00, k1=0x00, k2=0x00, k3=0x00;   /* cache key */
    for (int i=0; i<32; i++) {                         /* basic cycle start */
        v1 -= ((v0<<4) + k2) ^ (v0 + sum) ^ ((v0>>5) + k3);
        v0 -= ((v1<<4) + k0) ^ (v1 + sum) ^ ((v1>>5) + k1);
        sum -= delta;
    }   
	
	datafromboard[3] = (v1 & 0x000000ff);
	datafromboard[2] = (v1 & 0x0000ff00) >> 8;
	datafromboard[1] = (v1 & 0x00ff0000) >> 16;
	datafromboard[0] = (v1 & 0xff000000) >> 24;
	datafromboard[7] = (v0 & 0x000000ff);
	datafromboard[6] = (v0 & 0x0000ff00) >> 8;
	datafromboard[5] = (v0 & 0x00ff0000) >> 16;
	datafromboard[4] = (v0 & 0xff000000) >> 24;
}
void encrypt(uint8 *datatoboard ){
	uint32 v1 = datatoboard[3] | (datatoboard[2] << 8) | (datatoboard[1] << 16) | (datatoboard[0] << 24);
	uint32 v0 = datatoboard[7] | (datatoboard[6] << 8) | (datatoboard[5] << 16) | (datatoboard[4] << 24);
	
	uint32 delta = 0x9e3779b9,sum = 0;                     /* a key schedule constant */
    uint32 k0=0x00, k1=0x00, k2=0x00, k3=0x00;   /* cache key */
    for (int i=0; i < 32; i++) {                       /* basic cycle start */
        sum += delta;
        v0 += ((v1<<4) + k0) ^ (v1 + sum) ^ ((v1>>5) + k1);
        v1 += ((v0<<4) + k2) ^ (v0 + sum) ^ ((v0>>5) + k3);
    }   
	
	datatoboard[3] = (v1 & 0x000000ff);
	datatoboard[2] = (v1 & 0x0000ff00) >> 8;
	datatoboard[1] = (v1 & 0x00ff0000) >> 16;
	datatoboard[0] = (v1 & 0xff000000) >> 24;
	datatoboard[7] = (v0 & 0x000000ff);
	datatoboard[6] = (v0 & 0x0000ff00) >> 8;
	datatoboard[5] = (v0 & 0x00ff0000) >> 16;
	datatoboard[4] = (v0 & 0xff000000) >> 24;
	////
}

int main(int argc, char *argv[]) {
	ReturnCode retVal = FLP_SUCCESS, pStatus;
	//****************************************************************
	// In this line we declare the command option y which will implement the required functionality
	
	// struct arg_lit *loopOpt = arg_lit0("y", "loop", "             implements the loop required for CS254 program");
	// struct arg_str *ivpOpt = arg_str0("i", "ivp", "<VID:PID>", "            vendor ID and product ID (e.g 04B4:8613)");
	// struct arg_str *vpOpt = arg_str1("v", "vp", "<VID:PID[:DID]>", "       VID, PID and opt. dev ID (e.g 1D50:602B:0001)");
	// struct arg_str *fwOpt = arg_str0("f", "fw", "<firmware.hex>", "        firmware to RAM-load (or use std fw)");
	// struct arg_str *progOpt = arg_str0("p", "program", "<config>", "         program a device");
	// struct arg_end *endOpt   = arg_end(20);
	// void *argTable[] = {
	// 	loopOpt,ivpOpt, vpOpt, fwOpt, progOpt, endOpt
	// };
	const char *progName = "flcli";
	//int numErrors;
	struct FLContext *handle = NULL;
	FLStatus fStatus;
	const char *error = NULL;
	//const char *ivp = NULL;
	//const char *vp = NULL;
	bool isNeroCapable, isCommCapable;
	uint32 numDevices, scanChain[16], i;
	const char *line = NULL;
	uint8 conduit = 0x01;

	// if ( arg_nullcheck(argTable) != 0 ) {
	// 	fprintf(stderr, "%s: insufficient memory\n", progName);
	// 	FAIL(1, cleanup);
	// }

	//numErrors = arg_parse(argc, argv, argTable);

	// if ( helpOpt->count > 0 ) {
	// 	printf("FPGALink Command-Line Interface Copyright (C) 2012-2014 Chris McClelland\n\nUsage: %s", progName);
	// 	arg_print_syntax(stdout, argTable, "\n");
	// 	printf("\nInteract with an FPGALink device.\n\n");
	// 	arg_print_glossary(stdout, argTable,"  %-10s %s\n");
	// 	printf("\nModified for CS254 Lab projects\n\n");
	// 	FAIL(FLP_SUCCESS, cleanup);
	// }
	
	// if ( numErrors > 0 ) {
	// 	arg_print_errors(stdout, endOpt, progName);
	// 	fprintf(stderr, "Try '%s --help' for more information.\n", progName);
	// 	FAIL(FLP_ARGS, cleanup);
	// }

	fStatus = flInitialise(0, &error);
	CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
	char vp[] = "1d50:602b:0002";

	//vp = vpOpt->sval[0];

	printf("Attempting to open connection to FPGALink device %s...\n", vp);
	fStatus = flOpen(vp, &handle, NULL);
	if ( fStatus ) {
		//if ( ivpOpt->count ) {
			int count = 60;
			uint8 flag;
			char ivp[] = "1443:0007";
			printf("Loading firmware into %s...\n", ivp);
			fStatus = flLoadStandardFirmware(ivp, vp, &error);
			CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
			
			printf("Awaiting renumeration");
			flSleep(1000);
			do {
				printf(".");
				fflush(stdout);
				fStatus = flIsDeviceAvailable(vp, &flag, &error);
				CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
				flSleep(250);
				count--;
			} while ( !flag && count );
			printf("\n");
			if ( !flag ) {
				fprintf(stderr, "FPGALink device did not renumerate properly as %s\n", vp);
				FAIL(FLP_LIBERR, cleanup);
			}

			printf("Attempting to open connection to FPGLink device %s again...\n", vp);
			fStatus = flOpen(vp, &handle, &error);
			CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
	}

	printf(
		"Connected to FPGALink device %s (firmwareID: 0x%04X, firmwareVersion: 0x%08X)\n",
		vp, flGetFirmwareID(handle), flGetFirmwareVersion(handle)
	);


	isNeroCapable = flIsNeroCapable(handle);
	isCommCapable = flIsCommCapable(handle, conduit);

	// if ( progOpt->count ) {
	// 	printf("Programming device...\n");
	// 	if ( isNeroCapable ) {
	// 		fStatus = flSelectConduit(handle, 0x00, &error);
	// 		CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
	// 		fStatus = flProgram(handle, progOpt->sval[0], NULL, &error);
	// 		CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
	// 	} else {
	// 		fprintf(stderr, "Program operation requested but device at %s does not support NeroProg\n", vp);
	// 		FAIL(FLP_ARGS, cleanup);
	// 	}
	// }
	//if(loopOpt->count){
		if ( isCommCapable ) {
		    uint8 isRunning;
		    uint8 restrictions[4];
		    restrictions[0] = 255; //2000 restrictions
		    restrictions[1] = 255; //1000 restrictions
		    restrictions[2] = 255; //500 restrictions
		    restrictions[3] = 255; //100 restrictions

		    //selects the conduit, or the path for communication, ranges from 0 to 15
			fStatus = flSelectConduit(handle, conduit, &error);
			//check the correctness status 
			CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
			fStatus = flIsFPGARunning(handle, &isRunning, &error);
			CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
			//proceed to loop execution once we have established that the board is working perfectly
			if ( isRunning ) {
				//start csv read
				char buffer[1024] ;
				char *record,*line;
				uint32 mat[65536][4];
				FILE *fstream = fopen("myFile.csv","r");
				if(fstream == NULL)
				{
				  //printf("\n csv file opening failedc-c-c-c-c ");
				  return -1 ;
				}

				int start =1 ;
				int i=0;
				line=fgets(buffer,sizeof(buffer),fstream);
				while((line=fgets(buffer,sizeof(buffer),fstream))!=NULL){
					
					
					int j=0;
					record = strtok(line,",");

					while(record != NULL){
					 	int abc=atoi(record);
						mat[i][j++] = atoi(record) ;
					    record = strtok(NULL,",");
					}
				 	i++;
				 
				}
				// printf("%d\n", mat[0][0]);
				fclose(fstream);
				//end csv read
				int size=i;
				while(true){
					// printf("%s\n","working" );
					uint8 read = 0;
					uint8* data;
					data = &read;
					uint32 chan = 0;
					uint32 length = 1;
					bool cond1 = false;
					bool cond2 = false;
					flReadChannel(handle, (uint8)chan, length, data,&error);
					flReadChannel(handle, (uint8)chan, length, data,&error);
					// printf("%s\n","0" );
					//printf("%d\n",read );						
					if(read == 0x01){
						flSleep(1000);
						// printf("%s\n","0" );
						flReadChannel(handle, (uint8)chan, length, data,&error);

						if(read == 0x01){
							flSleep(1000);
							// printf("%s\n","0" );
							flReadChannel(handle, (uint8)chan, length, data,&error);
							if(read == 0x01){
								cond1 =true;

								printf("%s\n","found1" );
							}
						}
					}
					if(read == 0x02){
						flSleep(1000);
						flReadChannel(handle, (uint8)chan, length, data,&error);
						if(read == 0x02){
							flSleep(1000);
							flReadChannel(handle, (uint8)chan, length, data,&error);
							if(read == 0x02){
								cond2 =true;
							}
						}
					}
					int u_flag=0;
					if(cond1){
						uint8 datafromboard[8];
		
						//for(int k = 0;k < 8;k++){
						//	printf("%x\n", datafromboard[k]);
						//}
						printf("%s\n","starting to read from board" );
						for( int a = 0;a < 8;a++){
							chan = a+1;
							flSleep(100);
							flReadChannel(handle, (uint8)chan, length, data,&error);
							flReadChannel(handle, (uint8)chan, length, data,&error);
							// printf("%d\n",chan );
							datafromboard[a] = read;
							// printf("0X%x\n", datafromboard[a]);
						}
						uint8 available[4];
						for( int a = 0;a < 4;a++){
							chan = a + 19;
							flSleep(100);
							flReadChannel(handle, (uint8)chan, length, data,&error);
							flReadChannel(handle, (uint8)chan, length, data,&error);
							// printf("%d\n",chan );
							available[a] = read;
							// printf("0X%x\n", datafromboard[a]);
						}

						decrypt(datafromboard);
						for(int k = 0;k < 8;k++){
							printf("%s", "Data from board : ");
							printf("0X%x\n", datafromboard[k]);
						}
						printf("%s", "No of notes 2000 is :");
							printf("0X%x\n", available[0]);
							printf("%s", "No of notes 1000 is :");
							printf("0X%x\n", available[1]);
							printf("%s", "No of notes 500 is :");
							printf("0X%x\n", available[2]);
							printf("%s", "No of notes 100 is :");
							printf("0X%x\n", available[3]);
					


						uint16 userid,password;
						uint32 amount_requested;
						amount_requested = datafromboard[0] * 100 + datafromboard[1] * 500 + datafromboard[2] * 1000 + datafromboard[3] * 2000;
						uint32 amount = datafromboard[3]<<24 | datafromboard[2]<<16 | datafromboard[1]<<8 | datafromboard[0];
						// printf("%d\n", amount);
						userid = datafromboard[6] | (datafromboard[7] << 8); 
						password = datafromboard[4] | (datafromboard[5] << 8); 
						// password = password<<11 | password>>5;
						for(int j = 0;j < size;j++){
							if(mat[j][0] == userid){
								u_flag = 1;
								if(mat[j][1] == password){
									printf("%s\n","Valid user found");
									//user is admin and wants to upload money
									if(mat[j][2] == 1){
										printf("%s", "Amount deposited by admin : ");
										printf("%d\n", amount_requested);
										printf("%s\n", "User has admin privileges");
										mat[j][3] = mat[j][3] + amount_requested;
										//send back
										uint8 datatoboard[8];
										datatoboard[7] = 255;
										datatoboard[6] = 255;
										datatoboard[5] = 255;
										datatoboard[4] = 255;
										datatoboard[3] = datafromboard[3];// 2000 notes
										datatoboard[2] = datafromboard[2];// 1000 notes
										datatoboard[1] = datafromboard[1];// 500 notes
										datatoboard[0] = datafromboard[0];// 100 notes
										encrypt(datatoboard);
										chan = 9;
										read = 0x03;
										flWriteChannel(handle,(uint8) chan,length,data,&error);

										flSleep(1000);
										for(int k = 10; k < 18;k++){
											chan = k;
											read = datatoboard[k - 10];
											flSleep(100);
											flWriteChannel(handle,(uint8) chan,length,data,&error);	
											printf("%s","Writing data " );
											printf("%d", read);
											printf("%s"," to channel " );
											printf("%d\n", chan);
											flSleep(100);
										}
										fstream = fopen("myFile.csv","w+");
										fprintf(fstream, "%s\n","abcd, cvfg, xcxcx, xcxc" );
										for(int l = 0;l < size;l++){
											
											for (int m = 0; m < 4; ++m)
											{
												fprintf(fstream, "%d",mat[l][m] );
												fprintf(fstream, "%s", ",");
											}
											fprintf(fstream, "%s\n","" );
										}
										fclose(fstream);
									}
									//user wants to remove money
									else if(mat[j][2] == 0){
										if(mat[j][3] >= amount){
											// mat[j][3] = mat[j][3] - amount_requested;
											printf("%s\n", "Normal user, withdrawing money");
											bool is_possible;
											uint32 original_amount = amount; 
											uint8 n2000,n1000,n500,n100;
											n2000 = amount/2000;
											n2000 = min(min(available[0],restrictions[0]),n2000);
											amount = amount - 2000 * n2000;

											n1000 = amount/1000;
											n1000 = min(min(available[1],restrictions[1]),n1000);
											amount = amount - 1000 * n1000;

											n500 = amount/500;
											n500 = min(min(available[2],restrictions[2]),n500);
											amount = amount - 500 * n500;


											n100 = amount/100;
											n100 = min(min(available[3],restrictions[3]),n100);
											amount = amount - 100 * n100; 
											printf("%s", "user wants to remove this money");
											printf("%d\n",original_amount );
											if(amount == 0){
												is_possible = true;
												mat[j][3] = mat[j][3] - original_amount;
											}
											//dispense
											else if(amount > 0){
												is_possible = false;
												mat[j][3] = mat[j][3];
											}
											//dont dispense
											available[3] = (original_amount & 0x000000ff);
											available[2] = (original_amount & 0x0000ff00) >> 8;
											available[1] = (original_amount & 0x00ff0000) >> 16;
											available[0] = (original_amount & 0xff000000) >> 24;
											//send mback
											uint8 datatoboard[8];
											datatoboard[7] = restrictions[3];// 100 restrictions
											datatoboard[6] = restrictions[2];// 500 restrictions
											datatoboard[5] = restrictions[1];// 1000 restrictions
											datatoboard[4] = restrictions[0];// 2000 restrictions
											datatoboard[3] = datafromboard[0];// 2000 notes
											datatoboard[2] = datafromboard[1];// 1000 notes
											datatoboard[1] = datafromboard[2];// 500 notes
											datatoboard[0] = datafromboard[3];// 100 notes
											for( int a = 0;a < 8;a++){
												chan = a+1;
												flSleep(100);
												flReadChannel(handle, (uint8)chan, length, data,&error);
												flReadChannel(handle, (uint8)chan, length, data,&error);
												// printf("%d\n",chan );
												datafromboard[a] = read;
												// printf("0X%x\n", datafromboard[a]);
											}
											printf("%s\n","Channels 1 to 8 written" );
											encrypt(datatoboard);
											chan = 9;
											read = 0x01;
											flWriteChannel(handle,(uint8) chan,length,data,&error);
											for(int k = 10; k < 18;k++){
												chan = k;
												read = datatoboard[k - 10];
												flWriteChannel(handle,(uint8) chan,length,data,&error);
												flWriteChannel(handle,(uint8) chan,length,data,&error);	
												printf("%s","Writing to chan " );
												printf("%d\n", datatoboard[k - 10]);
											}
											printf("%s\n","Channels 10 to 17 written" );
											fstream = fopen("myFile.csv","w+");
											fprintf(fstream, "%s\n","abcd, cvfg, xcxcx, xcxc" );
											for(int l = 0;l < size;l++){
												
												for (int m = 0; m < 4; ++m)
												{
													fprintf(fstream, "%d",mat[l][m] );
													fprintf(fstream, "%s", ",");
												}
												fprintf(fstream, "%s\n","" );
											}
											fclose(fstream);
										}
										//user does not have enough money
										else{
											printf("%s","User does not have enough money requested" );
											printf("%d\n", amount);
											uint8 datatoboard[8];
											datatoboard[0] = 0;
											datatoboard[1] = 0;
											datatoboard[2] = 0;
											datatoboard[3] = 0;
											datatoboard[4] = 0;
											datatoboard[5] = 0;
											datatoboard[6] = 0;
											datatoboard[7] = 0;
											encrypt(datatoboard);
											//sendback
											chan = 9;
											read = 0x02;
											flWriteChannel(handle,(uint8) chan,length,data,&error);
											for(int k = 10; k < 18;k++){
												chan = k;
												read = datatoboard[k - 10];

												flWriteChannel(handle,(uint8) chan,length,data,&error);	
											}
											fstream = fopen("myFile.csv","w+");
											fprintf(fstream, "%s\n","abcd, cvfg, xcxcx, xcxc" );
											for(int l = 0;l < size;l++){
												
												for (int m = 0; m < 4; ++m)
												{
													fprintf(fstream, "%d",mat[l][m] );
													fprintf(fstream, "%s", ",");
												}
												fprintf(fstream, "%s\n","" );
											}
											fclose(fstream);
										}
									}
								}
								else{
									//incorrect password
									printf("%s\n", "notcorrect user ");
									uint8 datatoboard[8];
									datatoboard[0] = 0;
									datatoboard[1] = 0;
									datatoboard[2] = 0;
									datatoboard[3] = 0;
									datatoboard[4] = 0;
									datatoboard[5] = 0;
									datatoboard[6] = 0;
									datatoboard[7] = 0;
									encrypt(datatoboard);
									//sendback
									chan = 9;
									read = 0x04;
									flWriteChannel(handle,(uint8) chan,length,data,&error);
									for(int k = 10; k < 18;k++){
											chan = k;
											read = datatoboard[k - 10];
											flWriteChannel(handle,(uint8) chan,length,data,&error);	
									}
									break;
								}
							}	
						}
					}
					// if(cond2){
					// 	uint8 datafromboard[8];
					// 	for( int a = 0;a < 8;a++){
					// 		chan = a+1;
					// 		flReadChannel(handle, (uint8)chan, length, data,&error);
					// 		flReadChannel(handle, (uint8)chan, length, data,&error);
					// 		datafromboard[a] = read;
					// 	}
					// 	uint8 available[4];
					// 	for( int a = 0;a < 4;a++){
					// 		chan = a + 19;
					// 		flSleep(100);
					// 		flReadChannel(handle, (uint8)chan, length, data,&error);
					// 		flReadChannel(handle, (uint8)chan, length, data,&error);
					// 		// printf("%d\n",chan );
					// 		available[a] = read;
					// 		// printf("0X%x\n", datafromboard[a]);
					// 	}
					// 	decrypt(datafromboard);
					// 	for(int k = 0;k < 8;k++){
					// 		printf("OX%x\n", datafromboard[k]);
					// 	}
					// 	for(int k = 0;k < 4;k++){
					// 		printf("%s", "number of notes is");
					// 		printf("0X%x\n", available[k]);
					// 	}
					// 	uint16 userid,password;
					// 	uint32 amount_requested;
					// 	amount_requested = datafromboard[0] * 100 + datafromboard[1] * 500 + datafromboard[2] * 1000 + datafromboard[3] * 2000;
					// 	printf("%s", "Amount requested, cond2 : ");
					// 	printf("%d\n", amount_requested);
					// 	userid = datafromboard[6] | (datafromboard[7] << 8); 
					// 	password = datafromboard[4] | (datafromboard[5] << 8); 
					// 	// password = password<<11 | password>>5;
					// 	for(int j = 0;j < size;j++){
					// 		if(mat[j][0] == userid){
					// 			u_flag=1;
					// 			if(mat[j][1] == password){
					// 				printf("%s\n","Valid user found");
					// 				//user is admin and wants to upload money
					// 				if(mat[j][2] == 1){
					// 					printf("%s\n", "User has admin privileges");
					// 					mat[j][3] = mat[j][3] + amount_requested;
					// 					//send back
					// 					uint8 datatoboard[8];
					// 					datatoboard[7] = 0;
					// 					datatoboard[6] = 0;
					// 					datatoboard[5] = 0;
					// 					datatoboard[4] = 0;
					// 					datatoboard[3] = datafromboard[3];
					// 					datatoboard[2] = datafromboard[2];
					// 					datatoboard[1] = datafromboard[1];
					// 					datatoboard[0] = datafromboard[0];
					// 					for (int i = 0; i < 8; ++i)
					// 					{
					// 						printf("%s"," Data before encryption is :" );
					// 						printf("%d\n", datatoboard[i] );
					// 					}
					// 					encrypt(datatoboard);
					// 					chan = 9;
					// 					read = 0x03;
					// 					// flSleep(1000);
					// 					flWriteChannel(handle,(uint8) chan,length,data,&error);

					// 					printf("%s\n","writng to chan9 " );
					// 					for(int k = 10; k < 18;k++){
					// 						chan = k;
					// 						read = datatoboard[k - 10];
					// 						flSleep(100);
					// 						flWriteChannel(handle,(uint8) chan,length,data,&error);	
					// 						printf("%s","Writing data " );
					// 						printf("%d", read);
					// 						printf("%s"," to channel " );
					// 						printf("%d\n", chan);
					// 						flSleep(100);
					// 						// flWriteChannel(handle,(uint8) chan,length,data,&error);	
					// 						printf("%s","Chan Addr is : " );
					// 						printf("%d\n", k);
																					
					// 					}
					// 					printf("%s\n","All LEDs should be 1" );
					// 					fstream = fopen("myFile.csv","w+");
					// 					fprintf(fstream, "%s\n","abcd, cvfg, xcxcx, xcxc" );
					// 					for(int l = 0;l < size;l++){
											
					// 						for (int m = 0; m < 4; ++m)
					// 						{
					// 							fprintf(fstream, "%d",mat[l][m] );
					// 							fprintf(fstream, "%s", ",");
					// 						}
					// 						fprintf(fstream, "%s\n","" );
					// 					}
					// 					fclose(fstream);
					// 				}
					// 				//user wants to remove money
					// 				else if(mat[j][2] == 0){
					// 					if(mat[j][3] >= amount_requested){
					// 						//mat[j][3] = mat[j][3] - amount_requested;
					// 						//send mback
					// 						uint8 datatoboard[8];
					// 						datatoboard[7] = 0;
					// 						datatoboard[6] = 0;
					// 						datatoboard[5] = 0;
					// 						datatoboard[4] = 0;
					// 						datatoboard[3] = datafromboard[3];
					// 						datatoboard[2] = datafromboard[2];
					// 						datatoboard[1] = datafromboard[1];
					// 						datatoboard[0] = datafromboard[0];
					// 						encrypt(datatoboard);
					// 						chan = 9;
					// 						read = 0x01;
					// 						flWriteChannel(handle,(uint8) chan,length,data,&error);
					// 						for(int k = 10; k < 18;k++){
					// 							chan = k;
					// 							read = datatoboard[k - 10];
					// 							flWriteChannel(handle,(uint8) chan,length,data,&error);	
					// 						}
					// 						fstream = fopen("myFile.csv","w+");
					// 						fprintf(fstream, "%s\n","abcd, cvfg, xcxcx, xcxc" );
					// 						for(int l = 0;l < size;l++){
												
					// 							for (int m = 0; m < 4; ++m)
					// 							{
					// 								fprintf(fstream, "%d",mat[l][m] );
					// 								fprintf(fstream, "%s", ",");
					// 							}
					// 							fprintf(fstream, "%s\n","" );
					// 						}
					// 						fclose(fstream);
					// 					}
					// 					//user does not have enough money
					// 					else{
					// 						printf("%s\n", "user does not have enough money");
					// 						uint8 datatoboard[8];
					// 						datatoboard[0] = 0;
					// 						datatoboard[1] = 0;
					// 						datatoboard[2] = 0;
					// 						datatoboard[3] = 0;
					// 						datatoboard[4] = 0;
					// 						datatoboard[5] = 0;
					// 						datatoboard[6] = 0;
					// 						datatoboard[7] = 0;
					// 						encrypt(datatoboard);
					// 						//sendback
					// 						chan = 9;
					// 						read = 0x02;
					// 						flSleep(1000);
					// 						flWriteChannel(handle,(uint8) chan,length,data,&error);
					// 						printf("%s\n","Writing to channel 9" );
					// 						flSleep(1000);
					// 						for(int k = 10; k < 18;k++){
					// 							chan = k;
					// 							read = datatoboard[k - 10];
					// 							flSleep(100);
					// 							flWriteChannel(handle,(uint8) chan,length,data,&error);
					// 							flSleep(100);	
					// 						}
					// 						fstream = fopen("myFile.csv","w+");
					// 						fprintf(fstream, "%s\n","abcd, cvfg, xcxcx, xcxc" );
					// 						for(int l = 0;l < size;l++){
												
					// 							for (int m = 0; m < 4; ++m)
					// 							{
					// 								fprintf(fstream, "%d",mat[l][m] );
					// 								fprintf(fstream, "%s", ",");
					// 							}
					// 							fprintf(fstream, "%s\n","" );
					// 						}
					// 						fclose(fstream);
					// 					}
					// 				}
					// 			}
					// 			else{
					// 				//incorrect password
					// 				printf("%s\n", "not correct password ");
					// 				uint8 datatoboard[8];
					// 				datatoboard[0] = 0;
					// 				datatoboard[1] = 0;
					// 				datatoboard[2] = 0;
					// 				datatoboard[3] = 0;
					// 				datatoboard[4] = 0;
					// 				datatoboard[5] = 0;
					// 				datatoboard[6] = 0;
					// 				datatoboard[7] = 0;
					// 				encrypt(datatoboard);
					// 				//sendback
					// 				chan = 9;
					// 				read = 0x04;
					// 				flWriteChannel(handle,(uint8) chan,length,data,&error);
					// 				for(int k = 10; k < 18;k++){
					// 						chan = k;
					// 						read = datatoboard[k - 10];
					// 						flWriteChannel(handle,(uint8) chan,length,data,&error);	
					// 				}
					// 				fstream = fopen("myFile.csv","w+");
					// 				fprintf(fstream, "%s\n","abcd, cvfg, xcxcx, xcxc" );
					// 				for(int l = 0;l < size;l++){
										
					// 					for (int m = 0; m < 4; ++m)
					// 					{
					// 						fprintf(fstream, "%d",mat[l][m] );
					// 						fprintf(fstream, "%s", ",");
					// 					}
					// 					fprintf(fstream, "%s\n","" );
					// 				}
					// 				fclose(fstream);
					// 				break;
					// 			}
					// 		}
					// 	}
					// 	if(u_flag==0)
					// 	{
					// 		/* code */
					// 		printf("%s\n","nouserrrrr found" );
					// 		uint8 datatoboard[8];
					// 		datatoboard[0] = 0;
					// 		datatoboard[1] = 0;
					// 		datatoboard[2] = 0;
					// 		datatoboard[3] = 0;
					// 		datatoboard[4] = 0;
					// 		datatoboard[5] = 0;
					// 		datatoboard[6] = 0;
					// 		datatoboard[7] = 0;
					// 		encrypt(datatoboard);
					// 		//sendback
					// 		chan = 9;
					// 		read = 0x05;
					// 		flWriteChannel(handle,(uint8) chan,length,data,&error);
					// 		for(int k = 10; k < 18;k++){
					// 				chan = k;
					// 				read = datatoboard[k - 10];
					// 				flWriteChannel(handle,(uint8) chan,length,data,&error);	
					// 		}

					// 		fstream = fopen("myFile.csv","w+");
					// 		fprintf(fstream, "%s\n","abcd, cvfg, xcxcx, xcxc" );
					// 				for(int l = 0;l < size;l++){
										
					// 					for (int m = 0; m < 4; ++m)
					// 					{
					// 						fprintf(fstream, "%d",mat[l][m] );
					// 						fprintf(fstream, "%s", ",");
					// 					}
					// 					fprintf(fstream, "%s\n","" );
					// 				}
					// 				fclose(fstream);

					// 	}
					// }
				}
			}
			else {
				fprintf(stderr, "The FPGALink device at %s is not ready to talk - did you forget --xsvf?\n", vp);
				FAIL(FLP_ARGS, cleanup);
			}
		}
		else {
			fprintf(stderr, "Shell requested but device at %s does not support CommFPGA\n", vp);
			FAIL(FLP_ARGS, cleanup);
		}
	//}

cleanup:
	free((void*)line);
	flClose(handle);
	if ( error ) {
		fprintf(stderr, "%s\n", error);
		flFreeError(error);
	}
	return retVal;
}