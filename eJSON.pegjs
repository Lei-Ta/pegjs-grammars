/*
 * eJSON Parser
 * ============
 * 
 * Enhanced JSON from [1].
 * 
 * Based on the grammar from [2], which is based on the grammar from RFC 7159 [3].
 *
 * Note that JSON is also specified in ECMA-262 [4], ECMA-404 [5], and on the
 * JSON website [6] (somewhat informally). The RFC seems the most authoritative
 * source, which is confirmed e.g. by [7].
 *
 * [1] http://reml.lieta.lt
 * [2] https://github.com/pegjs/pegjs/blob/master/examples/json.pegjs
 * [3] http://tools.ietf.org/html/rfc7159
 * [4] http://www.ecma-international.org/publications/standards/Ecma-262.htm
 * [5] http://www.ecma-international.org/publications/standards/Ecma-404.htm
 * [6] http://json.org/
 * [7] https://www.tbray.org/ongoing/When/201x/2014/03/05/RFC7159-JSON
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
  
  input = convert(input);

}

/* ----- 2. JSON Grammar ----- */

JSON_text
  = ws value:value ws { return value; }

begin_array     = ws "[" ws
begin_object    = ws "{" ws
end_array       = ws "]" ws
end_object      = ws "}" ws
name_separator  = ws ":" ws
value_separator = ws "," ws

ws "whitespace" = [ \t\n\r]*

/* ----- 3. Values ----- */

value
  = boolean
  / null
  / named_array
  / named_object
  / object
  / array
  / number
  / string

boolean = false / true

false = "false" { return false; }
true  = "true"  { return true;  }

null  = "null"  { return null;  }

/* ----- 4. Objects ----- */

named_object
  = name:string object:object {
      result = {name:name};
      for (i in object) {
        if (i === "alt") {
          result["$"] = object["alt"];
        } else {
          result[i] = object[i];
        }
      }
      return result;
    }

object
  = begin_object
    members:(
      first:member
      rest:(value_separator m:member { return m; })*
      {
        var result = {}, i;
        var members = [first].concat(rest);

        for (i = 0; i < members.length; i++) {
          if (members[i].name === "$"){
            if (!result.hasOwnProperty("$")) result["$"] = [];
            result["$"].push(members[i].value);

          } else {
            result[members[i].name] = members[i].value;
          }
        }

        return result;
      }
    )?
    end_object
    { return members !== null ? members: {}; }

member
  = name:string name_separator value:value {
      return { name: name, value: value };
    }
  / value : value {
      if (value.name === "alt"){
        return { name : "alt", value: value["$"] };
      }
      return { name : "$", value: value };
    }


/* ----- 5. Arrays ----- */

named_array
  = obj:(
      obj:(named_object / object) 
        {if (!obj.hasOwnProperty("$")) obj["$"] = []; return obj;}
    / str: string 
        {return {name: str, "$" : []};}
    ) alt:alternative {
      result = [];
      for (i in alt){
        temp = {};
        for (var j in obj) temp[j] = obj[j];
        for (var j in alt[i]) {
          if (j === "$") {
            temp[j] = temp[j].concat(alt[i][j]);
          } else {
            temp[j] = alt[i][j];
          }
        }
        if (temp["$"].length < 1) delete temp["$"];
        result.push(temp);
      }
      return { name:"alt", "$" : result};
    }

alternative
  = begin_array
    objects:(
      first:object
      rest:(value_separator v:object { return v; })*
      { return [first].concat(rest); }
    )?
    end_array
    { return objects !== null ? objects : []; }
 

array
  = begin_array
    values:(
      first:value
      rest:(value_separator v:value { return v; })*
      { return [first].concat(rest); }
    )?
    end_array
    { return values !== null ? values : []; }

/* ----- 6. Numbers ----- */

number "number"
  = minus? int frac? exp? { return parseFloat(text()); }

decimal_point = "."
digit1_9      = [1-9]
e             = [eE]
exp           = e (minus / plus)? DIGIT+
frac          = decimal_point DIGIT+
int           = zero / (digit1_9 DIGIT*)
minus         = "-"
plus          = "+"
zero          = "0"

/* ----- 7. Strings ----- */

string "string"
  = quotation_mark chars:char* quotation_mark { return chars.join(""); }

char
  = unescaped
  / escape
    sequence:(
        '"'
      / "\\"
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

escape         = "\\"
quotation_mark = '"'
unescaped      = [\x20-\x21\x23-\x5B\x5D-\u10FFFF]

/* ----- Core ABNF Rules ----- */

/* See RFC 4234, Appendix B (http://tools.ietf.org/html/rfc4627). */
DIGIT  = [0-9]
HEXDIG = [0-9a-f]i
