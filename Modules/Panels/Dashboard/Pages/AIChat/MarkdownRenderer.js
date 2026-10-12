.pragma library

// ===================================
// Markdown Renderer for QML
// Block-based parser with enhanced rendering
// ===================================
// Adapted from unified-ai-panel plugin
// Original author: SUDOER1337 (based on j-1in's work)
// Repository: https://github.com/noctalia-dev/noctalia-plugins
// Licensed under MIT License

// --- Block classification ---
// Each block: { type: string, content: string, ...extra fields per type }
// Types: paragraph, header, code, bullet-list, numbered-list, task-list,
//        blockquote, table, hr, blank

// Parse markdown text into structured blocks for QML rendering
function parseBlocks(text) {
    if (!text || typeof text !== 'string') {
        return [{ type: "paragraph", content: text || "" }];
    }

    // Step 1: Extract fenced code blocks and protect them with placeholders
    var codeBlocks = [];
    var codeIndex = 0;
    var result = text.replace(/```(\w*)\n([\s\S]*?)```/g, function(match, lang, code) {
        var placeholder = '\x00CODEBLOCK_' + codeIndex + '\x00';
        codeBlocks[codeIndex] = { lang: lang || "", code: code.replace(/\n$/, "") };
        codeIndex++;
        return placeholder;
    });

    // Step 2: Split by double newlines into raw blocks
    var rawBlocks = result.split(/\n{2,}/);
    var blocks = [];

    for (var i = 0; i < rawBlocks.length; i++) {
        var raw = rawBlocks[i];
        if (raw.trim() === "") {
            continue; // Skip blank blocks
        }

        // Check for code block placeholder
        var codeMatch = raw.match(/^\x00CODEBLOCK_(\d+)\x00$/);
        if (codeMatch) {
            var idx = parseInt(codeMatch[1], 10);
            if (idx < codeBlocks.length) {
                blocks.push({
                    type: "code",
                    lang: codeBlocks[idx].lang,
                    content: codeBlocks[idx].code
                });
            }
            continue;
        }

        // Check for horizontal rule (---, ***, ___)
        if (/^[-*_]{3,}\s*$/.test(raw.trim())) {
            blocks.push({ type: "hr", content: "" });
            continue;
        }

        // Check for table (starts and ends with |)
        if (/^\|.+\|[\s\S]*\|.+\|$/.test(raw.trim())) {
            var table = parseTable(raw.trim());
            if (table) {
                blocks.push(table);
                continue;
            }
        }

        // Check for header (# to ######)
        var headerMatch = raw.match(/^(#{1,6})\s+(.+)$/);
        if (headerMatch) {
            blocks.push({
                type: "header",
                level: headerMatch[1].length,
                content: headerMatch[2].trim()
            });
            continue;
        }

        // Check for blockquote (> text, possibly multi-line)
        if (/^>\s/.test(raw)) {
            var quoteLines = raw.split("\n");
            var quoteContent = [];
            for (var q = 0; q < quoteLines.length; q++) {
                var ql = quoteLines[q].replace(/^>\s?/, "");
                quoteContent.push(ql);
            }
            blocks.push({
                type: "blockquote",
                content: quoteContent.join("\n")
            });
            continue;
        }

        // Check for task list items (- [ ] or - [x])
        var taskLines = raw.split("\n");
        var allTasks = true;
        var taskItems = [];
        for (var t = 0; t < taskLines.length; t++) {
            var taskMatch = taskLines[t].match(/^[-*+]\s+\[([ xX])\]\s+(.+)$/);
            if (taskMatch) {
                taskItems.push({
                    checked: taskMatch[1].toLowerCase() === "x",
                    text: taskMatch[2]
                });
            } else if (taskLines[t].trim() !== "") {
                allTasks = false;
                break;
            }
        }
        if (allTasks && taskItems.length > 0) {
            blocks.push({
                type: "task-list",
                items: taskItems
            });
            continue;
        }

        // Check for unordered list (- or * or + at line start)
        var ulLines = raw.split("\n");
        var allUL = true;
        var ulItems = [];
        for (var u = 0; u < ulLines.length; u++) {
            var ulMatch = ulLines[u].match(/^[-*+]\s+(.+)$/);
            if (ulMatch) {
                ulItems.push(ulMatch[1]);
            } else if (ulLines[u].trim() !== "") {
                allUL = false;
                break;
            }
        }
        if (allUL && ulItems.length > 0) {
            blocks.push({
                type: "bullet-list",
                items: ulItems
            });
            continue;
        }

        // Check for ordered list (N. at line start)
        var olLines = raw.split("\n");
        var allOL = true;
        var olItems = [];
        for (var o = 0; o < olLines.length; o++) {
            var olMatch = olLines[o].match(/^(\d+)\.\s+(.+)$/);
            if (olMatch) {
                olItems.push({ number: parseInt(olMatch[1], 10), text: olMatch[2] });
            } else if (olLines[o].trim() !== "") {
                allOL = false;
                break;
            }
        }
        if (allOL && olItems.length > 0) {
            blocks.push({
                type: "numbered-list",
                items: olItems
            });
            continue;
        }

        // Default: paragraph (may span multiple lines — rejoin single newlines)
        var paragraphText = raw.replace(/\n/g, " ").trim();
        if (paragraphText !== "") {
            blocks.push({ type: "paragraph", content: paragraphText });
        }
    }

    return blocks;
}

// Parse a markdown table into structured data
function parseTable(text) {
    var lines = text.split("\n");
    if (lines.length < 2) return null;

    var headers = [];
    var rows = [];
    var alignments = [];

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line.startsWith("|")) return null;

        var cells = line.split("|").map(function(c) { return c.trim(); });
        // Remove empty first/last from leading/trailing |
        if (cells.length > 0 && cells[0] === "") cells.shift();
        if (cells.length > 0 && cells[cells.length - 1] === "") cells.pop();

        if (i === 0) {
            headers = cells;
        } else if (/^[-:]+$/.test(cells.join("").replace(/\|/g, ""))) {
            // Alignment row (|---|:---|---:|)
            alignments = cells.map(function(c) {
                if (c.startsWith(":") && c.endsWith(":")) return "center";
                if (c.endsWith(":")) return "right";
                return "left";
            });
        } else {
            rows.push(cells);
        }
    }

    if (headers.length === 0) return null;

    return {
        type: "table",
        headers: headers,
        rows: rows,
        alignments: alignments
    };
}

// Simple escape function for QML
function escapeHtmlSimple(text) {
    return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

// Check if text contains Markdown patterns
function hasMarkdown(text) {
    if (!text || typeof text !== 'string') {
        return false;
    }

    var markdownPatterns = [
        /^#.+$/m,           // Headers
        /\*\*.+?\*\*/,      // Bold
        /\*.+?\*/,          // Italic
        /~~.+?~~/,          // Strikethrough
        /`.+?`/,            // Inline code
        /```[\s\S]*?```/,   // Code blocks
        /\[.+?\]\(.+?\)/,   // Links
        /^[\*\-\+] .+/m,    // Unordered lists
        /^\d+\. .+/m,       // Ordered lists
        /^[-*+]\s+\[[ xX]\]/m, // Task lists
        /^> .+/m,           // Blockquotes
        /^\|.+\|$/m,        // Tables
        /^[-*_]{3,}$/m      // Horizontal rules
    ];

    for (var i = 0; i < markdownPatterns.length; i++) {
        if (markdownPatterns[i].test(text)) {
            return true;
        }
    }

    return false;
}

// Parse inline markdown to HTML for Text.StyledText
function parseInline(text) {
    if (!text || typeof text !== 'string') {
        return text || "";
    }

    var result = text;

    // Escape HTML first to prevent injection (except for intentional markup)
    result = escapeHtmlSimple(result);

    // Bold (**text** and __text__)
    result = result.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
    result = result.replace(/__(.+?)__/g, '<b>$1</b>');

    // Italic (*text* and _text_)
    result = result.replace(/\*(.+?)\*/g, '<i>$1</i>');
    result = result.replace(/_(.+?)_/g, '<i>$1</i>');

    // Strikethrough (~~text~~)
    result = result.replace(/~~(.+?)~~/g, '<s>$1</s>');

    // Inline code (`code`) — styled as monospace with distinct color
    result = result.replace(/`([^`]+)`/g, '<font face="monospace" color="#C586C0">$1</font>');

    // Links [text](url)
    result = result.replace(/\[([^\]]+)\]\(([^)]+)\)/g, function(match, linkText, url) {
        if (isValidUrl(url)) {
            return '<a href="' + url + '">' + linkText + '</a>';
        }
        return linkText;
    });

    // Images ![alt](url) — render as italic placeholder
    result = result.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '<i>[$1]</i>');

    return result;
}

// Enhanced parser (kept for backward compatibility with streaming)
function parseMarkdownEnhanced(text) {
    if (!text || typeof text !== 'string') {
        return text;
    }

    // First, extract and protect code blocks
    var codeBlocks = [];
    var codeIndex = 0;
    var result = text.replace(/```(\w*)\n([\s\S]*?)```/g, function(match, lang, code) {
        var placeholder = '___CODE_BLOCK_' + codeIndex + '___';
        codeBlocks[codeIndex] = {
            lang: lang,
            code: escapeHtmlSimple(code.trim())
        };
        codeIndex++;
        return placeholder;
    });

    // Process inline formatting
    result = result.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
    result = result.replace(/__(.+?)__/g, '<b>$1</b>');
    result = result.replace(/\*(.+?)\*/g, '<i>$1</i>');
    result = result.replace(/_(.+?)_/g, '<i>$1</i>');
    result = result.replace(/~~(.+?)~~/g, '<s>$1</s>');

    // Process headers
    result = result.replace(/^# (.+)$/gm, '<b><font size="5">$1</font></b>');
    result = result.replace(/^## (.+)$/gm, '<b><font size="4">$1</font></b>');
    result = result.replace(/^### (.+)$/gm, '<b><font size="3">$1</font></b>');
    result = result.replace(/^#### (.+)$/gm, '<b>$1</b>');
    result = result.replace(/^##### (.+)$/gm, '<b>$1</b>');
    result = result.replace(/^###### (.+)$/gm, '<b>$1</b>');

    // Process inline code
    result = result.replace(/`([^`]+)`/g, '<font color="#C586C0"><tt>$1</tt></font>');

    // Process links with security validation
    result = result.replace(/\[([^\]]+)\]\(([^)]+)\)/g, function(match, text, url) {
        if (isValidUrl(url)) {
            return '<a href="' + escapeHtmlSimple(url) + '">' + escapeHtmlSimple(text) + '</a>';
        }
        return escapeHtmlSimple(text);
    });

    // Process images as italic placeholders
    result = result.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '<i>[$1]</i>');

    // Process unordered lists
    result = result.replace(/^[-*+]\s+\[([ xX])\]\s+(.+)$/gm, function(match, check, text) {
        var icon = check.toLowerCase() === "x" ? "☑" : "☐";
        return icon + " " + text;
    });
    result = result.replace(/^[\*\-\+] (.+)$/gm, '• $1');

    // Process ordered lists (preserve numbers)
    result = result.replace(/^(\d+)\. (.+)$/gm, '<b>$1.</b> $2');

    // Process blockquotes
    result = result.replace(/^>\s?(.+)$/gm, '<i>"$1"</i>');

    // Process horizontal rules
    result = result.replace(/^[-*_]{3,}$/gm, '─────────');

    // Restore code blocks
    for (var i = 0; i < codeBlocks.length; i++) {
        var placeholder = '___CODE_BLOCK_' + i + '___';
        var codeBlock = '<font color="#C586C0"><tt>' + codeBlocks[i].code + '</tt></font>';
        result = result.replace(placeholder, codeBlock);
    }

    // Process line breaks
    result = result.replace(/\n\n/g, '<br><br>');
    result = result.replace(/\n/g, '<br>');

    return result;
}

// URL validation function for security
function isValidUrl(url) {
    if (!url || typeof url !== 'string') return false;

    // Allow only safe protocols
    var allowedProtocols = ['http://', 'https://', 'mailto:', 'ftp://', 'file://'];
    var hasAllowedProtocol = false;

    for (var i = 0; i < allowedProtocols.length; i++) {
        if (url.startsWith(allowedProtocols[i])) {
            hasAllowedProtocol = true;
            break;
        }
    }

    if (!hasAllowedProtocol) return false;

    // Basic format validation
    var urlPattern = /^(https?|mailto|ftp):\/\/[^\s<>"{}|\\^`\[\]]+$/;
    return urlPattern.test(url);
}