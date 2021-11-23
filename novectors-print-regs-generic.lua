-- Given a parsed .SVD file (in Lua table form), print out some registers

-- Generic version. Useful for Pico and GD32?

-- Strip any trailing spaces or tabs, then append a newline.
function out(format, ...)
    local s = string.format(format, ...)
    s = s:gsub("[ 	]+$", "")
    io.write(s .. "\n")
end

-- Function to visit each branch and leaf of a tree.
--
-- Gets passed two functions: a function for branches and a function for
-- leaves. Returns a function that takes a tree and any number of
-- arguments, which are passed along as accumulators or whatever. visit()
-- doesn't know or care about them.
--
-- Also note that visit() does *not* recurse into branches! That's
-- fn_branch's job, if that's what it wants to do. visit() will, by
-- default, only visit the "top-level" nodes of tree.

function visit(fn_branch, fn_leaf)
    return function(tree, ...)
        for _, node in ipairs(tree) do
            local k, v = next(node)
            if type(v) == "table" then
                -- process branch node
                fn_branch(k, v, ...)
            else
                -- process leaf node
                fn_leaf(k, v, ...)
            end
        end
        return ...
    end
end

function hex(s)
    return tonumber(s, 16)
end

function muhex(num)
    return string.format("%04x_%04x", num >> 16, num % (2^16))
end

-- Convert parens to square brackets so muforth comments don't barf
function unparen(s)
    return (s:gsub("%(", "[")
             :gsub("%)", "]"))
end

-- RP2040 descriptions have embedded "\n" and can be quite long. Cut at
-- first "\n". Also cut at first ".".
function fix_descr(d)
    if not d then return "" end
    d = d:gsub("\\n", " ")
         :gsub("&amp;", "and")
         :gsub("&lt;", "<")
         :gsub("&gt;", ">")

    return "| " .. d
end

function nicer_chip_name(fname)
    local c = fname:match "^%w+"    -- strip extension
    c = c:gsub("x", "@")
         :upper()
         :gsub("@", "x")
    return c
end

function print_header(c, name, srcpath)
    out "( Automagically generated. DO NOT EDIT!"
    out "  Generated by https://github.com/nimblemachines/kinetis-chip-equates/"
    out("  from CMSIS-SVD source file %s)\n", srcpath)
    out("loading %s equates\n", name)

    out [[
sealed .equates.    ( chip equates and other constants for target)

( First, a few defining words, which we'll use to load the "equates".)
: equ     ( offset)  current preserve  .equates. definitions  constant ;
: vector  ( offset)  equ ;
: |  \ -- ;  ( | ignores the bit-fields that follow each register name)
: aka   .equates. chain' execute ;  ( for making synonyms)

hex]]
end

function max_name_length(t)
    local max = 0

    for _, e in ipairs(t) do
        max = math.max(e.name:len(), max)
    end

    return max
end
--[[
function print_vectors(c)
    local print_vector = function(vecfmt, name, vector, description)
        if not name:match "[Ii][Rr][Qq]" then
            name = name .. "_irq"
        end
        if not description then
            description = string.format("IRQ %2d", vector)
        else
            description = string.format("IRQ %2d: %s", vector, description)
        end
        out(vecfmt,
            (vector + 16) * 4,
            name,
            description)
    end

    out "\n( Vectors)"
    table.sort(c.interrupts, function(x, y)
        return x.vector < y.vector
    end)

    local longest = max_name_length(c.interrupts)
    local vecfmt = string.format("%%04x vector %%-%ds | %%s", longest + 3)

    for _, irq in ipairs(c.interrupts) do
        print_vector(vecfmt, irq.name, irq.vector, irq.description)
    end
    print_vector(
        vecfmt,
        "LAST",
        c.interrupts[#c.interrupts].vector + 1,
        "dummy LAST vector to mark end of vector table")
end
--]]
function print_periphs(c)
    out "\n( Register addresses)"

    table.sort(c.periphs, function(x, y)
        return x.base_address < y.base_address
    end)
    for _, periph in ipairs(c.periphs) do
        out("\n( %s)", periph.name)

        table.sort(periph.regs, function(x, y)
            return x.address_offset < y.address_offset
        end)

        local max_regname_len = 0
        for _, reg in ipairs(periph.regs) do
            max_regname_len = math.max(reg.name:len(), max_regname_len)
        end
        local regfmt = string.format("%%s equ %%-%ds %%s",
            max_regname_len + periph.name:len() + 3)

        for _, reg in ipairs(periph.regs) do
            out(regfmt,
                muhex(reg.address_offset + periph.base_address),
                periph.name .. "_" .. reg.name,
                fix_descr(reg.description))
        end
    end
end

function process_chip(chip)
    local append = table.insert
    local as_equates

    as_equates = visit(
        function(k, v, path, ctx)
            path = path.."/"..k
            if path == "/peripherals" then
                -- reset context
                ctx.periphs = {}
                ctx.interrupts = {}
            elseif path == "/peripherals/peripheral" then
                -- reset context
                ctx.periph = {}
            elseif path == "/peripherals/peripheral/interrupt" then
                -- reset context
                ctx.interrupt = {}
            elseif path == "/peripherals/peripheral/registers" then
                -- reset context
                ctx.regs = {}
            elseif path == "/peripherals/peripheral/registers/register" then
                -- reset context
                ctx.reg = {}
            elseif path == "/peripherals/peripheral/registers/register/fields" then
                -- reset context
                ctx.fields = {}
            elseif path == "/peripherals/peripheral/registers/register/fields/field" then
                -- reset context
                ctx.field = {}
            end

            -- Recurse into subtable
            as_equates(v, path, ctx)

            if path == "/peripherals/peripheral/registers/register/fields/field" then
                append(ctx.fields, ctx.field)
            elseif path == "/peripherals/peripheral/registers/register" then
                append(ctx.regs, ctx.reg)
            elseif path == "/peripherals/peripheral/interrupt" then
                local vector = tonumber(ctx.interrupt.value)
                append(ctx.interrupts, { name = ctx.interrupt.name, vector = vector })
            elseif path == "/peripherals/peripheral" then
                ctx.periph.regs = ctx.regs
                append(ctx.periphs, ctx.periph)
            elseif path == "/peripherals" then
                -- Nothing
            end
        end,

        function(k, v, path, ctx)
            if path == "" then
                ctx.chip[k] = v
            elseif path == "/peripherals/peripheral" then
                ctx.periph[k] = v
            elseif path == "/peripherals/peripheral/interrupt" then
                ctx.interrupt[k] = v
            elseif path == "/peripherals/peripheral/registers/register" then
                ctx.reg[k] = v
            elseif path == "/peripherals/peripheral/registers/register/fields/field" then
                ctx.field[k] = v
            end
        end)

    local path, ctx = as_equates(chip, "", { chip = {} })
    return ctx
end

-- arg 1 is lua file to process
-- arg 2 is href or path to SVD file

function doit()
    local ctx = process_chip(dofile(arg[1]))
    print_header(ctx, nicer_chip_name(arg[1]), arg[2])
--    print_vectors(ctx)
    print_periphs(ctx)
end

doit()
