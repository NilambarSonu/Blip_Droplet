# 02 — REA Setup & Tool Validation

## REA Repository Assessment

**Repository**: [github.com/morluto/rea](https://github.com/morluto/rea)
**Description**: "Reverse engineer anything with agents, from app behavior down to native binaries."
**npm package**: `rea-agents`

### REA Capabilities (from README)
- MCP-based integration with coding agents
- Native binary analysis via Hopper, Ghidra, or IDA providers
- JavaScript/Electron app analysis (static)
- CLI for terminal use
- Process capture and evidence-based findings

### Setup Command
```bash
npx rea-agents setup
```

### REA Requirements
- Node.js 22.x (≥22.19), 24.x (≥24.11), or 26+
- npm
- Native analysis requires a provider: Hopper, Ghidra, or IDA

## System Tool Availability

### Node.js Environment
| Tool | Version | Path | Status |
|---|---|---|---|
| Node.js | v24.21.0 | `~/.nvm/versions/node/v24.21.0/bin/node` | ✅ Compatible (≥24.11) |
| npm | 11.19.0 | `~/.nvm/versions/node/v24.21.0/bin/npm` | ✅ Available |

### Native Analysis Tools (Apple Command Line Tools)
| Tool | Path | Status |
|---|---|---|
| `otool` | `/usr/bin/otool` (llvm-otool, cctools-1040, LLVM 21.0.0) | ✅ |
| `nm` | `/usr/bin/nm` | ✅ |
| `strings` | `/usr/bin/strings` | ✅ |
| `codesign` | `/usr/bin/codesign` | ✅ |
| `lipo` | `/usr/bin/lipo` | ✅ |
| `plutil` | `/usr/bin/plutil` | ✅ |
| `file` | `/usr/bin/file` | ✅ |
| `objdump` | `/usr/bin/objdump` (Apple LLVM 21.0.0) | ✅ |
| `xcrun` | `/usr/bin/xcrun` | ✅ |
| `nettop` | `/usr/bin/nettop` | ✅ |
| `lsof` | `/usr/sbin/lsof` | ✅ |

### Disassemblers / Decompilers
| Tool | Status |
|---|---|
| Hopper Disassembler | ❌ Not installed |
| Ghidra | ❌ Not installed |
| IDA Pro | ❌ Not installed |
| `swift-demangle` | ❌ Not found (requires full Xcode) |

## REA Integration Assessment

### Antigravity MCP Integration
REA supports setup for Claude Code, Codex, Cursor, Gemini CLI, and others. The `npx rea-agents setup` command auto-detects supported agents and registers MCP servers.

**Assessment**: REA does **not** list Antigravity IDE as a supported agent in its setup documentation. However, REA's CLI tools can be invoked through Antigravity's terminal (`run_command`), which is the approach used in this investigation.

### Native Analysis Provider Status
REA requires Hopper, Ghidra, or IDA for native binary disassembly. **None are installed**, and the constraint prohibits installing Xcode.

**Workaround**: This investigation uses the installed Apple Command Line Tools (`otool`, `nm`, `strings`, `objdump`, `lipo`, `codesign`) for static analysis. These provide:
- Library dependency enumeration (`otool -L`)
- Symbol table extraction (`nm -g`)
- String extraction (`strings`)
- Object file dumping (`objdump`)
- Architecture inspection (`lipo -info`)

These tools successfully extracted detailed architectural information from the Blip binary, including Go source paths, protobuf definitions, module dependencies, and API endpoints.

### REA CLI Feasibility
REA's CLI can be invoked via terminal for JavaScript/Electron analysis. However, Blip is a **native Swift+Go application**, not an Electron app. REA's JavaScript analysis tools are therefore **not applicable** to this target.

For native analysis, REA would need a provider (Hopper/Ghidra/IDA). Without one installed, REA's native analysis workflow is **not operational** for this investigation.

## Tool Validation Summary

| Capability | Tool Used | Result |
|---|---|---|
| Bundle inspection | `plutil`, `codesign`, `file` | ✅ Complete |
| Architecture analysis | `lipo`, `otool` | ✅ Complete |
| Library dependencies | `otool -L` | ✅ Complete |
| Symbol extraction | `nm -g` | ✅ Complete |
| String analysis | `strings` + grep | ✅ Extensive |
| Code signing verification | `codesign -dv` | ✅ Complete |
| Entitlements extraction | `codesign -d --entitlements` | ✅ Complete |
| Process monitoring | `ps`, `top`, `lsof` | ✅ Complete |
| Network inspection | `lsof -i` | ✅ Complete |
| Disk usage | `du`, `find` | ✅ Complete |
| REA MCP integration | N/A | ⚠️ Not supported in Antigravity IDE |
| REA native analysis | N/A | ❌ No provider installed |
| Disassembly/decompilation | N/A | ❌ No disassembler available |

## Confidence Assessment
- **Confidence**: ★★★★☆ — All available tools worked correctly. The absence of a disassembler limits pseudocode recovery, but string and symbol analysis provided substantial architectural insight.
- **Limitation**: No decompiled pseudocode was recovered. All findings are from symbols, strings, library links, and build metadata embedded in the binary.
