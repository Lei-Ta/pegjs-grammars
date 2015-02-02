/*
 * reJSON Parser
 * =============
 * 
 * Reworked JSON from [1].
 *
 * Inspired by QML[2], JAML[3], Dōmo[4] and SIML[5].
 *
 * [1] http://reml.lieta.lt
 * [2] http://qt-project.org/doc/qt-5/qtqml-index.html
 * [3] https://github.com/edspencer/jaml
 * [4] http://jed.github.io/domo
 * [5] https://github.com/padolsey/SIML
 *
 */

/* ------1. Utilities ---------*/

{
  function objType(obj){
    return Object.prototype.toString.call(obj).replace(/\[object (.*?)\]/g, "$1")
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
}

start
  = _? el:( object / array ) __? !. {
      return el;
    }

/* ---- Expression ------------ */

expression
  = member
  / repetition
  / message
  / object
  / array
  / litteral
   
/* ---- Litteral -------------- */

litteral
  = boolean
  / null
  / number
  / string

boolean
  = "true"  { return true;  }
  / "false" { return false; }

null
  = "null"  { return null;  }

/* ---- Message --------------- */

member
  = n:name _? s:opname __? e:expression {
      return { "_TYPE_" : "_FIELD_", "_NAME_" : n , "_ACTION_" : "_SET_", "_VALUE_" : e };
    }
  
repetition
  = el:( message 
       / n:name {return { "_TYPE_" : "_MESSAGE_", "_NAME_" : n }; } 
       ) _? 
    arr:array {
      loop = [];
      if (arr) for (var i in arr) loop.push(
        { "_TYPE_" : "_ITERATION_", "_VALUE_" : arr[i] }
      );
      el["_LOOP_"] = loop;
      return el;
    }

message
  = n:(string / name) _? o:object {
      return { "_TYPE_" : "_MESSAGE_", "_NAME_" : n , "_VALUE_" : o } ;
    }
  / n:name {
      return { "_TYPE_" : "_MESSAGE_", "_NAME_" : n } ;
    }


/* ---- Array and object */

object
  = _? "{" _? es:expressions __? "}" { return es; }

array
  = _? "[" _? es:expressions __? "]" { return es; }

  
/* -------- Expressions ------- */

expressions
/**/
  = e:expression? _? s:separator _? es:expressions {
      result = [];
      if (e) result.push(e);
      if (s) result = result.concat(s);
      return result.concat(es);
    }
  / e:expression _? {
      return e;
    }
  / s:separator? _? {
      if (s) return s;
      return [];
    }
/**/
/** /
  = s:separator _? es:expressions {
      if (s) return s.concat(es);
      return es;
    }
  / e:expression _? es:expressions {
      if (e) return [e].concat(es);
      return es;
    }
  / e:expression _?
  / _? {
      return [];
    }/**/

/* ---- Name ------------------- */

name  
  = dotname / opname


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
      return { "_TYPE_" : "_MC_", "_VALUE_" : c.join('')};
    }
  / ";\\+" [+]? "\\"
    {return null;}

sl_comment
  = ";\\\\" c:([^\n\r+] / plus_wo_bsl)+ ("+\\" / [\n\r]) {
      result = c.join('').trim();
      if (result === "") return null;
      return { "_TYPE_" : "_SLC_", "_VALUE_" : c.join('') };
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
  = (separator /  _ )+ {return null;}

separator
  = sep:(sep_comment / semicolon / eol)+ { 
    result = []; 
    for (var i in sep) if(sep[i] !== null) result.push(sep[i]);
    if (result.length > 0) return result;
    return null;
  };

semicolon 
  = [;] {return null;}

eol 
  = [\n\r] {return null;}

altsep
  = _? "|" _? {return null;}

_
  = ( wsp_comment / [ \t] )+ {return null;}
