/************************* Required for every parser *************************/
#ifndef RAGEL_HAML_PARSER
#define RAGEL_HAML_PARSER

#include "ragel_parser_macros.h"

// the name of the language
const char *HAML_LANG = "haml";

// the languages entities
const char *haml_entities[] = {
  "space", "comment", "string", "any"
};

// constants associated with the entities
enum {
  HAML_SPACE = 0, HAML_COMMENT, HAML_STRING, HAML_ANY
};

/*****************************************************************************/

#include "ruby_parser.h"

%%{
  machine haml;
  write data;
  include common "common.rl";
  # EMBED(ruby)

  # Line counting machine

  action haml_ccallback {
    switch(entity) {
    case HAML_SPACE:
      ls
      break;
    case HAML_ANY:
      code
      break;
    case INTERNAL_NL:
      emb_internal_newline(HAML_LANG)
      break;
    case NEWLINE:
      emb_newline(HAML_LANG)
      break;
    }
  }

	action haml_indent_level_inc { current_indent_level++; }
	action haml_indent_level_res { current_indent_level = 0; }
  action haml_indent_level_set { prior_indent_level = current_indent_level; }

	haml_indent = ([ ]{2}) @haml_indent_level_inc;
  haml_indent_init = ([ ]{2} >haml_indent_level_res @haml_indent_level_inc)? haml_indent*;
  haml_eol = newline >haml_indent_level_res;
  haml_special_char = [/\.];

  haml_block_line_transition =
    haml_eol %{ entity = INTERNAL_NL;} %haml_ccallback
    ( newline %{ entity = INTERNAL_NL; } %haml_ccallback )*
    ( [ ]{2} when {current_indent_level < prior_indent_level} @haml_indent_level_inc )*
    ( [ ]{2} when {current_indent_level >= prior_indent_level} @haml_indent_level_inc)+;

  haml_block_comment =
    haml_indent_init '/' >haml_indent_level_set @comment (
      haml_block_line_transition
      |
      ws
      |
      (nonnewline-ws) @comment
    )*;

  haml_comment = haml_block_comment;

  haml_string = (haml_indent* (nonnewline - ws - haml_special_char) @code nonnewline*);
 
  haml_line := |*
    spaces          ${ entity = HAML_SPACE; } => haml_ccallback;
    haml_comment;
    haml_string;
    newline         ${ entity = NEWLINE;    } => haml_ccallback;
    ^space          ${ entity = HAML_ANY;   } => haml_ccallback;
  *|;
  
  # Entity machine

  action haml_ecallback {
    callback(HAML_LANG, haml_entities[entity], cint(ts), cint(te));
  }

  haml_entity := 'TODO:';
}%%

/************************* Required for every parser *************************/

/* Parses a string buffer with Haml markup.
 *
 * @param *buffer The string to parse.
 * @param length The length of the string to parse.
 * @param count Integer flag specifying whether or not to count lines. If yes,
 *   uses the Ragel machine optimized for counting. Otherwise uses the Ragel
 *   machine optimized for returning entity positions.
 * @param *callback Callback function. If count is set, callback is called for
 *   every line of code, comment, or blank with 'lcode', 'lcomment', and
 *   'lblank' respectively. Otherwise callback is called for each entity found.
 */
void parse_haml(char *buffer, int length, int count,
  void (*callback) (const char *lang, const char *entity, int start, int end)
  ) {
  init

  int prior_indent_level = 0;
  int current_indent_level = 0;
  
  %% write init;
  cs = (count) ? haml_en_haml_line : haml_en_haml_entity;
  %% write exec;

  // if no newline at EOF; callback contents of last line
  if (count) { process_last_line(HAML_LANG) }
}

#endif

/*****************************************************************************/