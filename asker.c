#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include "shared.h"

int main(int argc, char *argv[])
{
	char buf[1025];
	int l = 0, i = 0, tmp, len;
	int pipes_read[2], pipes_write[2];
	
	sscanf(getenv("SSHFS_PIPES"), "%d,%d;%d,%d", pipes_read, pipes_read + 1, pipes_write, pipes_write + 1);
	
	int wr = pipes_write[1], rd = pipes_read[0];
	
	dup(2);
	freopen(
#ifdef RELEASE
		"/dev/null"
#else
		"/tmp/sshfs-asker"
#endif
	, "w", stderr);
	
	fprintf(stderr, "asker pipes: read = %d, %d; write = %d, %d\n", pipes_read[0], pipes_read[1], pipes_write[0], pipes_write[1]);
	
	//fprintf(stderr, "PASSWORD: %s\n", getenv("SSHFS_GUI_PASS"));
	
	#define AUTHENTICITY_CHECK_INVITATION "The authenticity of host"
	
	//fprintf(stderr, "First argument: %s\n", argv[1]);
	
	if(argc > 1 && !strncmp(argv[1], AUTHENTICITY_CHECK_INVITATION, sizeof(AUTHENTICITY_CHECK_INVITATION)-1))
	{
		//printf("yes");
		
		//return 0;
		
		fprintf(stderr, "Preparing to ask for a message\n");
		fflush(stderr);
		
		tmp = ACTION_AUTHENTICITY_CHECK;
		write(wr, &tmp, sizeof(tmp));
		
		len = strlen(argv[1]);
		
		fprintf(stderr, "File opened, writing the length of message\n");
		fflush(stderr);
		
		write(wr, &len, sizeof(len));
		
		fprintf(stderr, "Writing the message itself\n");
		fflush(stderr);
		
		write(wr, argv[1], len);
		
		fprintf(stderr, "Reading number of bytes of a response\n");
		fflush(stderr);
		
		read(rd, &len, sizeof(len));
		
		if(len > sizeof(buf) - 1) len = sizeof(buf) - 1;
		
		fprintf(stderr, "Reading the response itself\n");
		fflush(stderr);
		
		read(rd, buf, len);
		buf[len] = 0;
		
		printf("%s", buf);
		
		return 0;
	}
	
	//#define PASS_INVITE "Password:"
	
	/* there are different invitations, not only Password: */
	
	//fprintf(stderr, "Password asked\n");
	
	//fprintf(stderr,"ARGS:\n");
	//for(i = 0; i < argc; i++)
	//{
	//	fprintf(stderr,"%s\n", argv[i]);
	//}
	
	/*fprintf(stderr,"\nINPUT:\n");
	
	//fflush(stdout);
	
	while( (l = read(0, buf, sizeof(buf)-1) ) )
	{
		buf[l] = 0;
		fprintf(stderr, "%s", buf);
		//fflush(stdout);
	}*/
	
	if(1)//!strncmp(argv[argc-1], PASS_INVITE, sizeof(PASS_INVITE)-1))
	{
		tmp = ACTION_ASK_PASSWORD;
		write(wr, &tmp, sizeof(tmp));
		
		read(rd, &len, sizeof(len));
		
		// highly improbable, that anyone would enter a password with length >= 1024 characters
		// but, just-in-case, we will not make any assumptions on it's length
		
		while( (tmp = read(rd, buf, len >= sizeof(buf)-1 ? sizeof(buf)-1 : len)) > 0 )
		{
			buf[tmp] = 0;
			len -= tmp;
			
			printf("%s", buf);
			
			if(len <= 0) break;
		}
		
		return 0;
	}
	
	
	return 0;
}
