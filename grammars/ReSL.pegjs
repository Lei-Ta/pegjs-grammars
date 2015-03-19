/*
 * ReSL Parser
 * =============
 * 
 * Reworked Serialization Language from [1].
 *
 * Inspired by QML[2], JAML[3], Dōmo[4], SIML[5] and JSSL[6].
 *
 * [1] http://re.leita.lt
 * [2] http://qt-project.org/doc/qt-5/qtqml-index.html
 * [3] https://github.com/edspencer/jaml
 * [4] http://jed.github.io/domo
 * [5] https://github.com/padolsey/SIML
 * [6] http://re.leita.lt/jssl
 *
 */

/* ------1. Utilities ---------*/

{
  function objType(obj){
    return Object.prototype.toString.call(obj).replace(/\[object (.*?)\]/g, "$1");
  }

  function start(input){
    if (input && input.length > 1) return input;
    if (input && input.length > 0) return input[0];
    return null;
  }

  function separations(expr, sep, rest){
    result = [];
    if (expr) result = [expr];
    if (sep) result = result.concat(sep);
    if (rest) return result.concat(rest);
    return result;
  }

  function boolean(input){
    if (input > 0) return true;
    if (input < 1) return false;
  }

  function nil(){
    return null;
  }

  function member(name, action, expr){
      result = { "_field_" : name, "_action_" : action };
      type = objType(expr);
      if (type === "Array" && expr.length === 1) {
        result["_content_"] = expr[0];
      } else if (type === "Object") {
        for (var i in expr) result[i] = expr[i];
      } else {
        result["_content_"] = expr;
      }
      return result;
  };

  function loop(type, left, operator, right){
    switch(type){
      case "merge":
        result = left;
        break;
      case "dotname":
        result = { "_name_" : left };
        break;
      case "group/simple":
        if (objType(sp) === "Array" && sp.length === 1) {
          result = {"_content_" : left[0]};
        } else {
          result = { "_content_" : left };
        }
        break;
    }
    result["_loop_"] = right;
    return result;
  }

  function parts(type, input){
    switch(type){
      case "group":
        result = input;
        break;
      default:
        result = [input];
    }
    return result;
  }
  
  function merge(name, suffices, parts){
    result = { "_name_" : name };
    if (suffices) result["_content_"] = suffices;
    if (parts) if (result["_content_"]) {
      result["_content_"] = result["_content_"].concat(parts);
    } else {
      result["_content_"] = parts;
    }
    if (result["_content_"] && result["_content_"].length === 1) 
      result["_content_"] = result["_content_"][0];
    return result;
  }

  function join(array){
    return array.join("");
  }

  function field(name, action, value){
    return {"_field_" : name , "_action_" : action, "_content_" : value};
  }

  function toFloat(sign, integer, float){
    return parseFloat(sign + integer.join("") + "." + float.join(""));
  }

  function toInt(sign, integer){
    return parseFloat(sign + integer.join(""));
  }

  function string(char){
    result = char.join("").replace(/[ \t]+/gm, " ");
    if (result.search(/[\n\r]/gm) > -1)
      result = result.split(/[\n\r]+/);
    return result;
  }

  function simple_string(char){
    return char.join("").replace(/[ \t]+/gm, " ");
  }

  function ml_comment(c){
    result = c.join('').trim();
    if (result === "") return null;
    return { "_mlc_" : c.join('') };
  }

  function sl_comment(c){
    result = c.join('').trim();
    if (result === "") return null;
    return { "_slc_" : c.join('') };
  }

  function separator(sep){
    result = []; 
    for (var i in sep) if(sep[i] !== undefined) result.push(sep[i]);
    if (result.length > 0) return result;
    return undefined;
  }

  function dig2str(digits){
    return String.fromCharCode(parseInt(digits, 16));
  }

}

start
  = !.
  / _? el:separations __? !. {
      return start(el);
    }

/* -------- Separations ------- */

separations
  = e:expression _? sep:separator _? rest:separations? _? {
      return separations(e, sep, rest);
    }
  / sep:separator _? rest:separations? _? {
      return separations(null, sep, rest);
    }
  / e:expression _? {
      return separations(e, null, null);
    }
    
/* ---- Expression ------------ */

expression
  = member
  / loop
  / merge
  / parts
  / simple
   
/* ---- Litteral -------------- */

simple
  = number
  / boolean
  / null
  / string

boolean
  = "true"  { return boolean(1); }
  / "false" { return boolean(0); }

null
  = "null"  { return nil();  }

/* ---- Member ---------------- */

member
  = dn:dotname _? s:action __? e:expression {
      return member(dn, s, e);
    }

loop
  = dn:merge _? s:operator __? g:group {
      return loop("merge", dn, s, g);
    }
  / dn:dotname _? s:operator __? g:group {
      return loop("dotname", dn, s, g);
    }
  / sp:(group/simple) _? s:operator __? g:group {
      return loop("group/simple", sp, s, g);
    }
  
/* ---- Repetition ------------ */

parts
  = _  m:merge   { return parts("merge", m); }
  / _? g:group   { return parts("group", g); } 
  / _  s:simple  { return parts("simple", s); }

  
    

/* ---- Message --------------- */

merge
  = sn:dotname sf:suffices? p:parts? {
      return merge(sn, sf, p);
    }

/* ---- Group ----------------- */

group
  = _? "(" _? es:separations _? ")" {
      return es; // simplified
    }
  / _? "(" _? ")" { return [];} 


/* ---- Name ------------------ */

dotname
  = d:dot n:namestr {return d + n;}
  / namestr

opname
  = d:dot o:operator+ { return d + join(o); }
  /       o:operator+ { return     join(o); }

name
  = namestr

namestr
  =  f:fchar m:mchar* l:lchar? { return text(); }

suffices
  = _? s:( 
      _? n:( "#" { return "id";    } / "@" { return "class"; } ) s:namestr { 
        return field (n , "=", s ); 
      }
    )+ { return s; }

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

action
  = [=]

operator
  = [*]


/* ---------- Number ----------- */

number
  = s:sign i:[0-9]+ [.,] f:[0-9]+ {
      return toFloat(s, i, f);
    }
  / s:sign i:[0-9]+ {
      return toInt(s, i);
    }

sign
  = [+-] / ""

DIGIT  = [0-9]
HEXDIG = [0-9a-f]i

/* ---------- String ----------- */

string
  = cs:(
    '"' cs:('\\"' / char / special)* '"' { return cs; }
  / "'" cs:("\\'" / char / special)* "'" { return cs; } ) {
    return string(cs);
  }

simpleString
  = cs:(
    '"' cs:('\\' '"' / char)* '"' {return cs;}
  / "'" cs:("\\" "'" / char)* "'" {return cs;} ) {
    return simple_string(cs);
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
          return dig2str(digits);
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

/* ---------- Comments -------- */


sep_comment
  = ml_comment
  / sl_comment

ml_comment
  = ";\\+" c:([^+] / plus_wo_bsl)+ "+\\" {
       return ml_comment(c);
    }
  / ";\\+" [+]? "\\"
    {return null;}

sl_comment
  = ";\\\\" c:([^\n\r+] / plus_wo_bsl)+ ("+\\" / [\n\r]) {
       return sl_comment(c);
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

/* --------- Space ------------ */

__ 
  = (separator /  _ )+ {return undefined;}

separator
  = sep:(sep_comment / semicolon / eol)+ {
    return separator(sep); 
  };

semicolon 
  = [;] {return undefined;}

eol 
  = [\n\r] {return undefined;}

altsep
  = _? "|" _? {return undefined;}

_
  = ( wsp_comment / [ \t] )+ {return undefined;}