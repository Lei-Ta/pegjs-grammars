/*
 * JSSL Parser
 * =============
 * 
 * Reworked JSON from [1].
 *
 * Inspired by QML[2], JAML[3], Dōmo[4] and SIML[5].
 *
 * [1] http://reml.leita.lt/jssl
 * [2] http://qt-project.org/doc/qt-5/qtqml-index.html
 * [3] https://github.com/edspencer/jaml
 * [4] http://jed.github.io/domo
 * [5] https://github.com/padolsey/SIML
 *
 */

/* ------1. Utilities ---------*/

{
  function objType(obj){
    return Object.prototype.toString.call(obj).replace(/\[object (.*?)\]/g, "$1");
  }

  function convert(input){
    if (objType(input) === "Null"){
      return "Null";
    } else if (objType(input) === "Undefined"){
      return "Undefined";
    } else if (objType(input) !== "String"){
      return JSON.stringify(input);
    }
    return input;
  }

  function normalizedStr(obj){
    var result, temp;
    switch (objType(obj)){
      case "Array":
        result = obj;
        break;
      case "Object":
        result = {};
        for (var i in obj) {
          if (i === "_content_" && objType(obj[i]) !== "Array"){
            temp = obj[i];
            result[i] = [temp];
          } else {
            result[i] = obj[i];
          }
        }
        if (!result.hasOwnProperty("_content_")) result["_content_"] = [];
        break;
      default:
        temp = obj;
        result = [temp];
        break;
    }
    return JSON.stringify(result);
  }

  function merge(elemStr, repStr){
    var result = {}, elemTmp, repTmp, tmp;
    elemTmp = JSON.parse(elemStr);
    repTmp = JSON.parse(repStr);
    if (objType(elemTmp) === "Array"){
      if (objType(repTmp) === "Array"){
        result = elemTmp.concat(repTmp);
      } else {
        tmp = elemTmp.concat(repTmp["_content_"]);
        result = repTmp;
        delete result["_content_"];
        result["_content_"] = tmp;
      }
    }  else {
      result = elemTmp;
      if (objType(repTmp) === "Array"){
        result["_content_"] = elemTmp["_content_"].concat(repTmp);
      } else {
        tmp = elemTmp["_content_"].concat(repTmp["_content_"]);
        delete result["_content_"];
        delete repTmp["_content_"];
        for (var i in repTmp)  result[i] = repTmp[i];
        result["_content_"] = tmp;
      }
    }
      
    if (objType(result) === "Object") if (result["_content_"].length === 1) {
      result["_content_"] = result["_content_"][0];
    } else if (result["_content_"].length < 1){
      delete result["_content_"];
    }
    return result;
  }

  function looping(elem, reps){
    var result = [], elemStr, temp, repStr;
    elemStr = normalizedStr(elem);
    for (var i in reps) {
      repStr = normalizedStr(reps[i]);
      temp = merge(elemStr, repStr);
      result.push(temp);
    }
    return {"_loop_" : result};
  }

}

start
  = !.
  / _? el:separations __? !. {
      if (el && el.length > 1) return el;
      if (el && el.length > 0) return el[0];
      return null;
    }

/* -------- Separations ------- */

separations
  = e:expression _? sep:separator _? rest:separations? _? {
      result = [e];
      if (sep) result = result.concat(sep);
      if (rest) return result.concat(rest);
      return result;
    }
  / sep:separator _? rest:separations? _? {
      result = [];
      if (sep) result = result.concat(sep);
      if (rest) return result.concat(rest);
      return result;
    }
  / e:expression _? {
      return [e];
    }
    
/* ---- Expression ------------ */

expression
  = member
  / repetition
  / merge
  / object
  / array
  / simple
   
/* ---- Litteral -------------- */

simple
  = number
  / boolean
  / null
  / string

boolean
  = "true"  { return true;  }
  / "false" { return false; }

null
  = "null"  { return null;  }

/* ---- Member ---------------- */

member
  = n:strname _? s:opname __? e:expression {
      result = { "_field_" : n, "_action_" : s, "_content_": e};
      return result;
    }
  
/* ---- Repetition ------------ */

repetition
  = mo:(merge/object) _? rep:array {
      return looping(mo, rep);
    }
  / a:array _? rep:array {
      return looping(a, rep);    }
  / s:simple _? rep:array {
      return looping(s, rep);
    }


/* ---- Message --------------- */

merge
  = sn:strname o:object {
      result = { "_name_": sn };
      for (var i in o) {
        if (
            objType(o[i]) === "Object" && 
            o[i].hasOwnProperty("loop")
        ){
          o["_content_"] = o["_content_"].concat(o[i]["_loop_"]);
        } else {
          result[i] = o[i];
        }
      }
      return result;
    }
  / n: name { return { "_name_": n };}


/* ---- Object ---------------- */

object
  = _? "{" _? es:separations _? "}" {
      properties = {}; content = [];
      if (es) for (var i in es){
        if (objType(es[i]) === "Object" && es[i].hasOwnProperty("_loop_")){
          content = content.concat(es[i]["_loop_"])
        } else if (es[i].hasOwnProperty("_property_")){
          properties[es[i]["_property_"]] = es[i]["_content_"];
        } else {
          content.push(es[i]);
        }
        
      } 
      if (content.length > 1) {
        properties["_content_"] = content;
      } else if (content.length > 0) {
        properties["_content_"] = content[0];
      }
      return properties;
    }
  / _? "{" _? "}" { return {};} 

/* ---- Array ----------------- */

array
  = _? "[" _? es:separations _? "]" {
      if (es) return es;
      return [];
    }
  / _? "[" _? "]" { return [];} 

  
/* ---- Name ------------------- */

strname
  = string
  / name

name  
  = dotname


dotname
  = d:dot n:symbol {return d+n;}
  / symbol

opname
  = d:dot o:operator+ { return d + o.join(""); }
  /       o:operator+ { return     o.join(""); }

symbol
  =  f:fchar m:mchar* l:lchar? { return text(); }

dot 
  = [\x2E]

fchar
  = idchar

mchar
  = [\x2D] 
  / DIGIT
  / idchar 
  / [\x80\x82-\x8C\x8E]
  / [\x91-\x9C\x9E]

lchar
  = idchar / DIGIT

idchar         
  = [\x41-\x5A\x5F]
  / [\x61-\x7A\xC0-\xFE]

operator
  = [:]


/* ---------- Number ----------- */

number
  = s:sign i:[0-9]+ [.,] f:[0-9]+ {
      return parseFloat(s+i.join("")+"."+f.join(""))
    }
  / s:sign i:[0-9]+ {
      return parseInt(s+i.join(""))
    }

sign
  = [+-] / ""

DIGIT  = [0-9]
HEXDIG = [0-9a-f]i

/* ---------- String ----------- */

string
  = cs:(
    '"' cs:('\\"' / char / special)* '"' {return cs;}
  / "'" cs:("\\'" / char / special)* "'" {return cs;} ) {
    result = cs.join("").replace(/[ \t]+/gm, " ");
    if (result.search(/[\n\r]/gm) > -1)
      result = result.split(/[\n\r]+/);
    return result;
  }

simpleString
  = cs:(
    '"' cs:('\\' '"' / char)* '"' {return cs;}
  / "'" cs:("\\" "'" / char)* "'" {return cs;} ) {
    return cs.join("").replace(/[ \t]+/gm, " ");
  }

char
  = unescaped
  / ignore
  / escape
    sequence:(
        "\\"
      / "/"
      / "b" { return "\b"; }
      / "f" { return "\f"; }
      / "n" { return "\n"; }
      / "r" { return "\r"; }
      / "t" { return "\t"; }
      / "u" digits:$(HEXDIG HEXDIG HEXDIG HEXDIG) {
          return String.fromCharCode(parseInt(digits, 16));
        }
    )
    { return sequence; }

ignore         
  = "\\\\" ("\\"!";" / [^\n\r\\])* ("\\;" / [\n\r])
      {return " ";}

escape         
  = "\\"

unescaped      
  = [\x20-\x21\x23-\x26\x28-\x5B\x5D-\u10FFFF]

special
  = [\x09-\x0B\x0D]

/* ---------- Comments ------- */


sep_comment
  = ml_comment
  / sl_comment

ml_comment
  = ";\\+" c:([^+] / plus_wo_bsl)+ "+\\" {
      result = c.join('').trim();
      if (result === "") return null;
      return { "_mlc_" : c.join('')};
    }
  / ";\\+" [+]? "\\"
    {return null;}

sl_comment
  = ";\\\\" c:([^\n\r+] / plus_wo_bsl)+ ("+\\" / [\n\r]) {
      result = c.join('').trim();
      if (result === "") return null;
      return {"_slc_" : c.join('')};
    }
  / ";\\\\" ("+\\" / [\n\r])
    {return null;}

plus_wo_bsl
  = plus:[+]![\\] {return plus;}

wsp_comment
  = "\\+" c:([^+] / [+]![\\])+ "+\\" 
  / "\\+" [+]? "\\"
  / "\\\\" c:([^\n\r+] / [+]![\\])+ ("+\\" / [\n\r]) 
  / "\\\\" ("+\\" / [\n\r])

/*--------- Space -----------*/

__ 
  = (separator /  _ )+ {return undefined;}

separator
  = sep:(sep_comment / semicolon / eol)+ { 
    result = []; 
    for (var i in sep) if(sep[i] !== undefined) result.push(sep[i]);
    if (result.length > 0) return result;
    return undefined;
  };

semicolon 
  = [;] {return undefined;}

eol 
  = [\n\r] {return undefined;}

altsep
  = _? "|" _? {return undefined;}

_
  = ( wsp_comment / [ \t] )+ {return undefined;}