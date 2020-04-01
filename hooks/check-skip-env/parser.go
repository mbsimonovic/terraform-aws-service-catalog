package main

import (
	"go/ast"
	"go/parser"
	"go/token"
	"strings"

	"github.com/gruntwork-io/gruntwork-cli/errors"
)

// hasAnySkipEnvSetCalls parses the golang test file and looks for any os.Setenv calls that correspond to setting the
// SKIP environment variable for terratest stages.
func hasAnySkipEnvSetCalls(path string) (bool, error) {
	file, err := parseSourceFile(path)
	if err != nil {
		return false, err
	}
	setenvCalls := findSetenvCalls(file)
	for _, setenvCall := range setenvCalls {
		if isSkipEnvSetCall(setenvCall) {
			return true, nil
		}
	}
	return false, nil
}

// parseSourceFile uses the golang parser to parse the test source file into an AST representation.
func parseSourceFile(path string) (*ast.File, error) {
	fset := token.NewFileSet()
	f, err := parser.ParseFile(fset, path, nil, parser.AllErrors)
	if err != nil {
		return nil, errors.WithStackTrace(err)
	}
	return f, nil
}

// findSetenvCalls looks for all the call expressions that correspond to os.Setenv calls in each of the top level
// function bodies of the file. This will recursively look in expression bodies that are likely to contain a Setenv call
// for setting terratest SKIP environment variables. These are:
// - top level function call expressions
// - function literal bodies of t.Run calls
// - bodies of range statements
func findSetenvCalls(file *ast.File) []*ast.CallExpr {
	allFuncs := getAllTopLevelFunctions(file)
	setenvCalls := []*ast.CallExpr{}
	for _, fBody := range allFuncs {
		funcSetenvCalls := getAllOsSetenvCalls(fBody)
		setenvCalls = append(setenvCalls, funcSetenvCalls...)
	}
	return setenvCalls
}

// getAllTopLevelFunctions return a mapping from function name to body of all the top level functions declared in the
// file.
func getAllTopLevelFunctions(file *ast.File) map[string]*ast.BlockStmt {
	funcs := map[string]*ast.BlockStmt{}
	for _, decl := range file.Decls {
		funcDecl, isFunc := decl.(*ast.FuncDecl)
		if isFunc {
			funcs[funcDecl.Name.Name] = funcDecl.Body
		}
	}
	return funcs
}

// getAllOsSetenvCalls will look for all the os.Setenv calls in a function body, strategically searching for likely
// places. That is, this function deliberately ignores statements that are unlikely to contain os.Setenv calls that
// correspond to terratest SKIP stages, such as defer. The expressions that this will search are:
// - top level function call expressions
// - function literal bodies of t.Run calls
// - bodies of range statements
// This will recursively look in expression bodies if necessary.
func getAllOsSetenvCalls(codeBody *ast.BlockStmt) []*ast.CallExpr {
	stmts := codeBody.List
	setenvCalls := []*ast.CallExpr{}
	for _, stmt := range stmts {
		switch typedStmt := stmt.(type) {
		case *ast.ExprStmt:
			expr := typedStmt.X
			callExpr, isCallExpr := expr.(*ast.CallExpr)
			if isCallExpr && isOsSetenvCall(callExpr) {
				setenvCalls = append(setenvCalls, callExpr)
			} else if isCallExpr && isTRunCall(callExpr) {
				// Recurse into the subtest function body
				body := getFuncBodyFromTRunCall(callExpr)
				if body != nil {
					calls := getAllOsSetenvCalls(body)
					setenvCalls = append(setenvCalls, calls...)
				}
			}
		case *ast.RangeStmt:
			// recurse in to the range statement body
			calls := getAllOsSetenvCalls(typedStmt.Body)
			setenvCalls = append(setenvCalls, calls...)
		}
		// ASSUMPTION: all other kinds of statements (e.g., defer) are unlikely to include any form of os.Setenv call.
	}
	return setenvCalls
}

// getFuncBodyFromTRunCall returns the function body of the function being passed into a t.Run call, if it is a function
// literal. Otherwise, returns nil.
func getFuncBodyFromTRunCall(tRunCallExpr *ast.CallExpr) *ast.BlockStmt {
	funcArg := tRunCallExpr.Args[1]
	// ASSUMPTION: We ignore functions passed in by name, since those are presumably top level functions. Instead, we
	// focus only on function literals.
	funcLiteral, isFuncLiteral := funcArg.(*ast.FuncLit)
	if isFuncLiteral {
		return funcLiteral.Body
	}
	return nil
}

// isSkipEnvSetCall takes a os.Setenv call expression and identifies if this is trying to set a terratest SKIP
// environment variable.
func isSkipEnvSetCall(callExpr *ast.CallExpr) bool {
	envNameArgExpr := callExpr.Args[0]
	// ASSUMPTION: skip env calls always use string literals for the name
	literalExpr, isLiteralExpr := envNameArgExpr.(*ast.BasicLit)
	if isLiteralExpr && literalExpr.Kind == token.STRING {
		// It is a skip env set call if os.Setenv env name arg starts with SKIP_.
		// Note that the literal value is wrapped in quotes so we include that in the check.
		return strings.HasPrefix(literalExpr.Value, "\"SKIP_")
	}
	return false
}

// isOsSetenvCall takes a golang call expression and determines if it is calling os.Setenv.
func isOsSetenvCall(callExpr *ast.CallExpr) bool {
	selector, isSelector := callExpr.Fun.(*ast.SelectorExpr)
	if !isSelector {
		return false
	}

	ident, isIdent := selector.X.(*ast.Ident)
	if !isIdent {
		return false
	}

	return ident.Name == "os" && selector.Sel.Name == "Setenv"
}

// isTRunCall returns true if the function call is a call to t.Run.
func isTRunCall(callExpr *ast.CallExpr) bool {
	selector, isSelector := callExpr.Fun.(*ast.SelectorExpr)
	if !isSelector {
		return false
	}

	ident, isIdent := selector.X.(*ast.Ident)
	if !isIdent {
		return false
	}

	return ident.Name == "t" && selector.Sel.Name == "Run"
}
