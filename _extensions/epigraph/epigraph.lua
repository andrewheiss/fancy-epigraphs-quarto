-- epigraph shortcode
function epigraph(args, kwargs)
  local text = args[1] or ""
  local source = kwargs["source"]

  if quarto.doc.isFormat("html") then
    return html_epigraph(text, source)
  elseif quarto.doc.isFormat("latex") or quarto.doc.isFormat("pdf") then
    return latex_epigraph(text, source)
  elseif quarto.doc.isFormat("typst") then
    return typst_epigraph(text, source)
  else
    return generic_epigraph(text, source)
  end
end


-- Convert a Markdown-based string to a specific format
function convert_markdown(text, format)
  local parsed = pandoc.read(text, "markdown")
  return pandoc.write(parsed, format)
end


-- Convert a Markdown-based string to a specific format, but without the parent 
-- paragraph (i.e. with HTML, convert_markdown() returns content wrapped 
-- in <p></p>; this returns what's inside that paragraph)
function convert_inline_markdown(text, format)
  if not text then return "" end

  local parsed = pandoc.read(text, "markdown")
  if #parsed.blocks > 0 and parsed.blocks[1].t == "Para" then
    local inlines = parsed.blocks[1].content
    local inline_doc = pandoc.Pandoc({ pandoc.Plain(inlines) })
    return pandoc.write(inline_doc, format)
  else
    return pandoc.utils.stringify(text)
  end
end


-- Build HTML output like this:
--
-- <div class="epigraph-wrapper clearfix">
--   <figure class="text-end w-50 float-end figure">
--     <blockquote class="epigraph blockquote">
--       <p>Something neat</p>
--     </blockquote>
--     <figcaption class="blockquote-footer">
--       Someone
--     </figcaption>
--   </figure>
-- </div>
function html_epigraph(text, source)
  text_parsed = convert_markdown(text, "html")
  source_parsed = convert_inline_markdown(source, "html")

  local source_element = source_parsed ~= "" 
    and '<figcaption class="blockquote-footer">' .. source_parsed .. '</figcaption>\n'
    or ""

  local template = {
    '<div class="epigraph-wrapper clearfix">\n',
    '<figure class="text-end w-50 float-end">\n',
    '<blockquote class="epigraph">\n', 
    text_parsed, 
    '</blockquote>\n',
    source_element,
    '</figure>\n',
    '</div>\n'
  }

  return pandoc.RawBlock('html', table.concat(template, ""))
end


-- Build LaTeX output like this:
--
-- \epigraph{Something neat}{--- Someone}
function latex_epigraph(text, source)
  text_parsed = convert_markdown(text, "latex")
  source_parsed = convert_inline_markdown(source, "latex")

  local source_element = source_parsed ~= "" 
    and '---' .. source_parsed .. ''
    or ""

  local template = {
    '\\epigraph{',
    text_parsed, 
    '}{',
    source_element,
    '}'
  }

  return pandoc.RawBlock('latex', table.concat(template, ""))
end


-- Build typst output like this:
--
-- #{
--   show quote: set align(left)
--   show quote: set pad(left: 65%, right: 0em)
--
--   quote(
--     block: true,
--     attribution: [Someone]
--   )[Something neat]
-- }
function typst_epigraph(text, source)

  text_parsed = convert_markdown(text, "typst")
  source_parsed = convert_inline_markdown(source, "typst")

  local source_element = source_parsed ~= "" 
    and 'attribution: [' .. source_parsed .. ']'
    or ""

  local template = {
  '#{\n',
  '  show quote: set align(left)\n',
  '  show quote: set pad(left: 65%, right: 0em)\n',
  '  quote(\n',
  '    block: true,\n',
       source_element,
  '  )[', text_parsed, ']\n',
  '}\n'
  }

  return pandoc.RawBlock('typst', table.concat(template, ""))
end


-- Build all other formats as if they came from Markdown like this:
-- 
-- > Something neat
-- > 
-- > ---Someone
function generic_epigraph(text, source)
  -- Work with pandoc blocks instead of strings to keep things format-agnostic
  local text_blocks = pandoc.read(text, "markdown").blocks
  local blockquote_content = {}
  
  for _, block in ipairs(text_blocks) do
    table.insert(blockquote_content, block)
  end

  -- Add source if it exists attribution if provided, with the markdown-style "--- Source" format
  if source and pandoc.utils.stringify(source) ~= "" then
    local source_parsed = pandoc.read(pandoc.utils.stringify(source), "markdown")

    -- This is the same as convert_inline_markdown(), but format-agnostic
    local source_inlines = {}
    if #source_parsed.blocks > 0 and source_parsed.blocks[1].t == "Para" then
      source_inlines = source_parsed.blocks[1].content
    else
      source_inlines = {pandoc.Str(pandoc.utils.stringify(source))}
    end

    local attribution = pandoc.Para({
      pandoc.Str("—"),
      pandoc.Space(),
      table.unpack(source_inlines)
    })

    table.insert(blockquote_content, attribution)
  end

  -- Make the final actual blockquote
  local blockquote = pandoc.BlockQuote(blockquote_content)

  return pandoc.Div({blockquote}, {class = "epigraph"})
end


-- Return the final output!
return {
  ["epigraph"] = epigraph
}
