import macros
import sequtils
import tables

macro sym_inject*(params: varargs[untyped]): untyped =
  assert len(params) <= 3

  var p = params.last
  var register: string = "injector_handlers"
  var procName: string = p.name.strVal

  if len(params) > 1:
    for child in params.children:
      if child == p: break
      if child.kind != nnkExprEqExpr:
        error("Unexpected parameter: " & child.repr)
      elif child[0].strVal == "register":
        if child[1].kind != nnkStrLit:
          error("`register` paramater: must be string", child)
        register = child[1].strVal
      elif child[0].strVal == "name":
        if child[1].kind != nnkStrLit:
          error("`name` paramater: must be string")
        procName = child[1].strVal
      else:
        error("Unexpected parameter: " & child.repr, child)

  p.expectKind(nnkProcDef)

  result = newStmtList()

  let
    varName = "real_" & procName
    typeName = "real_" & procName & "_Type"
    varNameIdent  = newIdentNode(varName)
    typeNameIdent = newIdentNode(typeName)
  
  result.add nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      newIdentNode(typeName),
      newEmptyNode(),
      nnkProcTy.newTree(
        p.params,
        nnkPragma.newTree(
          newIdentNode("gcsafe"),
          newIdentNode("stdcall")
        )
      )
    )
  )

  result.add quote do:
    var `varNameIdent`: `typeNameIdent`

  let body = newStmtList()
  body.add quote do:
    if `varNameIdent` == nil:
      `varNameIdent` = cast[`typeNameIdent`](real_dlsym(cast[pointer](RTLD_NEXT), `procName`))
    
  copyChildrenTo(p.body, body)

  result.add newProc(
    nnkPostfix.newTree(
      newIdentNode("*"),
      newIdentNode(procName)
    ),
    toSeq(p.params.children),
    body,
    nnkProcDef,
    nnkPragma.newTree(
      newIdentNode("exportc"),
      newIdentNode("dynlib")
    )
  )

  var import_tables = newStmtList()
  import_tables.add nnkImportStmt.newTree(
    newIdentNode("tables")
  )

  result.add import_tables

  if len(register) > 0:
    result.add newAssignment(
      nnkBracketExpr.newTree(
        newIdentNode(register),
        newLit(procName)
      ),
      newIdentNode(procName)
    )

  echo result.repr

#eof