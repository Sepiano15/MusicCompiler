%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <windows.h>

#define DEBUG	0

#define	 MAXSYM	100
#define	 MAXSYMLEN	20
#define	 MAXTSYMLEN	15
#define	 MAXTSYMBOL	MAXSYM/2
#define STMTLIST 500

typedef struct nodeType {
	int token;
	int tokenval;
	struct nodeType *son;
	struct nodeType *brother;
	} Node;

#define YYSTYPE Node*
	
int tsymbolcnt=0;
int errorcnt=0;
int octave = 4;
int i = 0;
int length = 0;
int speed = 250;
int repCnt = 1;

float C_node = 16.4;
float Cs_node = 17.3;
float D_node = 18.4;
float Ds_node = 19.4;
float E_node = 20.6;
float F_node = 21.8;
float Fs_node = 23.1;
float G_node = 24.4;
float Gs_node = 26.0;
float A_node = 27.5;
float As_node = 29.1;
float B_node = 30.9;

float playNode = 0;

FILE *yyin;
FILE *fp;

extern char symtbl[MAXSYM][MAXSYMLEN];
extern int maxsym;
extern int lineno;

void DFSTree(Node*);
Node * MakeOPTree(int, Node*, Node*);
Node * MakeNode(int, int);
Node * MakeListTree(Node*, Node*);
void codegen(Node* );
void prtcode(int, int);
void JudgeNode(int);

void	dwgen();
int	gentemp();
void	assgnstmt(int, int);
void	numassgn(int, int);
void	addstmt(int, int, int);
void	substmt(int, int, int);
int		insertsym(char *);
%}

%token	ID NUM STMTEND START END OCT P PLAY SPEED REP REPEND

%%
program	: START stmt_list END	{ if (errorcnt==0) {codegen($2); dwgen();} }
		;

stmt_list: 	stmt_list stmt 	{$$=MakeListTree($1, $2);}
		|	stmt			{$$=MakeListTree(NULL, $1);}
		| 	error STMTEND	{ errorcnt++; yyerrok;}
		;

stmt	: 	P expr_list REPEND		{ $$=MakeOPTree(P, $2, NULL); }
		|	SPEED term STMTEND		{ $$=MakeNode(SPEED, $2->tokenval);}
		|   REP expr_list REPEND {if(repCnt==1){repCnt=0;$$=MakeOPTree(REP, $2, NULL); $$->brother=MakeOPTree(REP, $2, NULL);}}
		;

expr_list: 	expr_list expr 	{$$=MakeListTree($1, $2);}
		|	expr			{$$=MakeListTree(NULL, $1);}

expr	: 	PLAY term term   { $$=MakeOPTree(PLAY, $2, $3); }
		|	OCT term { $$=MakeNode(OCT, $2->tokenval);}

term	:	ID		{ /* ID node is created in lex */ }
		|	NUM		{ /* NUM node is created in lex */ }
		;


%%
int main(int argc, char *argv[]) 
{
	printf("\nsample CBU compiler v2.0\n");
	printf("(C) Copyright by Jae Sung Lee (jasonlee@cbnu.ac.kr), 2022.\n");
	
	if (argc == 2)
		yyin = fopen(argv[1], "r");
	else {
		printf("Usage: cbu2 inputfile\noutput file is 'a.asm'\n");
		return(0);
		}
		
	fp=fopen("a.asm", "w");
	
	yyparse();
	
	fclose(yyin);
	fclose(fp);

	if (errorcnt==0) 
		{ printf("Successfully compiled. Assembly code is in 'a.asm'.\n");}
}

yyerror(s)
char *s;
{
	printf("%s (line %d)\n", s, lineno);
}


Node * MakeOPTree(int op, Node* operand1, Node* operand2)
{
Node * newnode;

	newnode = (Node *)malloc(sizeof (Node));
	newnode->token = op;
	newnode->tokenval = op;
	newnode->son = operand1;
	newnode->brother = NULL;
	operand1->brother = operand2;
	return newnode;
}

Node * MakeNode(int token, int operand)
{
Node * newnode;

	newnode = (Node *) malloc(sizeof (Node));
	newnode->token = token;
	newnode->tokenval = operand; 
	newnode->son = newnode->brother = NULL;
	return newnode;
}

Node * MakeListTree(Node* operand1, Node* operand2)
{
Node * newnode;
Node * node;

	if (operand1 == NULL){
		newnode = (Node *)malloc(sizeof (Node));
		newnode->token = newnode-> tokenval = STMTLIST;
		newnode->son = operand2;
		newnode->brother = NULL;
		return newnode;
		}
	else {
		node = operand1->son;
		while (node->brother != NULL) node = node->brother;
		node->brother = operand2;
		return operand1;
		}
}

void codegen(Node * root)
{
	DFSTree(root);
}

void DFSTree(Node * n)
{
	if (n==NULL) return;
	DFSTree(n->son);
	prtcode(n->token, n->tokenval);
	DFSTree(n->brother);
	
}

void prtcode(int token, int val)
{
	switch (token) {
	case ID:
		JudgeNode(val);
		fprintf(fp, "PLAY %s node in %d\n", symtbl[val], length);
		break;
	case PLAY:
		for (i=0;i<octave;i++){
			playNode *= 2;
		}
		Beep(playNode,length);
		break;
	case NUM:
		length = val*speed;
		break;
	case OCT:
		fprintf(fp, "OCTAVE %d\n", val);
		octave = val;
		break;
	case SPEED:
		fprintf(fp, "SPEED %d\n", val);
		speed = val;
		break;
	case STMTLIST:
	default:
		break;
	};
}


/*
int gentemp()
{
char buffer[MAXTSYMLEN];
char tempsym[MAXSYMLEN]="TTCBU";

	tsymbolcnt++;
	if (tsymbolcnt > MAXTSYMBOL) printf("temp symbol overflow\n");
	itoa(tsymbolcnt, buffer, 10);
	strcat(tempsym, buffer);
	return( insertsym(tempsym) ); // Warning: duplicated symbol is not checked for lazy implementation
}
*/
void dwgen()
{
int i;
	fprintf(fp, "HALT\n");
	fprintf(fp, "$ -- END OF EXECUTION CODE AND START OF VAR DEFINITIONS --\n");

// Warning: this code should be different if variable declaration is supported in the language 
	for(i=0; i<maxsym; i++) 
		fprintf(fp, "DW %s\n", symtbl[i]);
	fprintf(fp, "END\n");
}

void JudgeNode(int val){
	if(strcmp(symtbl[val],"C")==0)	playNode = C_node;
	else if(strcmp(symtbl[val],"Cs")==0) playNode = Cs_node;
	else if(strcmp(symtbl[val],"D")==0) playNode = D_node;
	else if(strcmp(symtbl[val],"Ds")==0) playNode = Ds_node;
	else if(strcmp(symtbl[val],"E")==0) playNode = E_node;
	else if(strcmp(symtbl[val],"F")==0) playNode = F_node;
	else if(strcmp(symtbl[val],"Fs")==0) playNode = Fs_node;
	else if(strcmp(symtbl[val],"G")==0) playNode = G_node;
	else if(strcmp(symtbl[val],"Gs")==0) playNode = Gs_node;
	else if(strcmp(symtbl[val],"A")==0) playNode = A_node;
	else if(strcmp(symtbl[val],"As")==0) playNode = As_node;
	else if(strcmp(symtbl[val],"B")==0) playNode = B_node;
	else if(strcmp(symtbl[val],"R")==0) playNode = 0.0;
}