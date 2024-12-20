fmt:
	v fmt -w .

test:
	v . && ./vyacc -d examples/calc.y

calc:
	flex examples/calc.l
	yacc examples/calc.y
	clang y.tab.c
