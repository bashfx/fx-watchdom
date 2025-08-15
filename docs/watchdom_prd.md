# Product Requirements Document: watchdom
**Domain Availability Monitoring System**

---

## Executive Summary

**Product**: watchdom  
**Version**: 2.0.0  
**Type**: Command-line utility  
**Target Users**: Domain investors, developers, system administrators, legal professionals  
**Core Value Proposition**: Intelligent, phase-aware domain availability monitoring with real-time notifications and extensible TLD support

## Problem Statement

Domain acquisition requires precise timing and constant monitoring. Current solutions are either:
- **Manual**: Requiring constant human attention and prone to missing opportunities
- **Basic**: Simple polling without intelligent interval adjustment
- **Expensive**: SaaS solutions with vendor lock-in and recurring costs
- **Limited**: Support only major TLDs without extensibility

**Pain Points**:
- Missing domain drops due to infrequent checking
- Wasting resources with unnecessarily aggressive polling
- No awareness of critical time windows (grace periods, target deadlines)
- Lack of automated notifications for unattended monitoring
- Inability to monitor non-standard TLDs

## Product Vision

A self-contained, intelligent domain monitoring system that adapts its behavior based on temporal context, provides extensible TLD support, and integrates seamlessly into automated workflows while respecting rate limits and system resources.

## Target Audience

### Primary Users
- **Domain Investors**: Monitoring expiring premium domains
- **Brand Protection Teams**: Watching for defensive domain registrations
- **Legal Professionals**: Tracking domain disputes and recovery timelines

### Secondary Users  
- **Developers**: Waiting for project domain availability
- **System Administrators**: Monitoring corporate domain infrastructure
- **Researchers**: Studying domain registration patterns

## Core Features & Requirements

### 🎯 **Phase-Aware Intelligent Polling**

**Requirement**: Dynamic interval adjustment based on temporal proximity to target events

**Phases**:
- **PRE Phase** (>30min to target): Conservative polling at base interval
- **HEAT Phase** (≤30min to target): Aggressive ramping (30s → 10s)  
- **GRACE Phase** (0-3hrs past target): Sustained high-frequency monitoring
- **COOL Phase** (>3hrs past target): Progressive cooldown to prevent resource waste

**Visual Feedback**:
- Phase-specific color coding and glyphs
- Real-time countdown displays
- Clear temporal context indicators

**Business Value**: 
- Maximizes chance of capture during critical windows
- Minimizes resource usage during low-probability periods
- Prevents indefinite aggressive polling

### 🌐 **Extensible TLD Registry System**

**Requirement**: Support for any TLD through configurable whois server/pattern mappings

**Built-in Support**:
- `.com/.net` via Verisign (`"No match for"`)
- `.org` via PIR (`"(NOT FOUND|Domain not found)"`)

**User Extensibility**:
- Configuration file: `~/.watchdomrc`
- Format: `TLD|WHOIS_SERVER|AVAILABLE_PATTERN`
- Runtime TLD addition via CLI

**Management Commands**:
- `list_tlds`: Display all configured TLD patterns
- `add_tld`: Add new TLD configuration  
- `test_tld`: Validate TLD patterns against test domains

**Business Value**:
- Supports emerging TLDs and country codes
- Future-proof against new domain extensions
- Allows specialized monitoring configurations

### 📧 **Automated Notification System**

**Requirement**: Background email alerts for critical events without interrupting monitoring

**Trigger Events**:
- **SUCCESS**: Domain becomes available for registration
- **TARGET_REACHED**: Configured target time reached (grace period entry)
- **GRACE_ENTERED**: Extended grace period threshold exceeded (3+ hours)

**Configuration**:
- Environment variable based (fail-safe if incomplete)
- Support multiple email backends (mutt, msmtp, sendmail)
- Non-blocking operation (continues monitoring on email failure)

**Business Value**:
- Enables unattended long-term monitoring
- Provides audit trail of monitoring events
- Supports distributed team notifications

### 🕒 **Advanced Time Management**

**Requirement**: Sophisticated datetime handling and countdown capabilities

**Features**:
- Multiple datetime input formats (ISO, epoch, natural language)
- Cross-platform date parsing (GNU/BSD compatibility)
- Real-time countdown with human-readable formatting
- Local/UTC time display options
- Grace period management with user intervention prompts

**Standalone Time Mode**:
- Time-only countdown without domain monitoring
- Useful for general deadline tracking
- Consistent output format for scripting

**Business Value**:
- Supports diverse user time preferences and systems
- Enables integration with scheduling systems
- Provides standalone utility value

### 🛡️ **Resource Management & Safety**

**Requirement**: Responsible resource usage with built-in safety mechanisms

**Rate Limiting**:
- Configurable base intervals with minimum thresholds
- Warnings for aggressive polling settings
- Automatic cooldown after extended monitoring

**Graceful Degradation**:
- User prompts after extended grace periods
- Configurable exit conditions
- Maximum poll count limits

**System Integration**:
- Standard exit codes for automation
- Quiet modes for background operation
- Signal handling for clean shutdown

**Business Value**:
- Prevents service abuse and potential blacklisting
- Reduces infrastructure costs
- Maintains good standing with whois providers

## Technical Architecture

### 🏗️ **BashFX Compliance Framework**

**Architectural Alignment Requirements**:
- **Standard Interface**: Implementation of `main()`, `dispatch()`, `options()` super-ordinal functions
- **Function Ordinality**: Strict hierarchy with `do_*` (high-order/dispatchable), `_*` (mid-level helpers), `__*` (low-level literals)
- **XDG+ Compliance**: User configuration files follow `~/.watchdomrc` pattern (though not using full XDG paths for this utility)
- **Self-Contained**: All functionality built with standard Unix tools (bash, whois, date, grep, sed)
- **Rewindable**: Clear installation/uninstallation path through simple file placement
- **Predictable Variables**: Standard local variable naming (`ret`, `res`, `str`, `path`, `this`)
- **Semicolon Usage**: Proper statement termination following BashFX style guidelines
- **Comment Structure**: Structured function documentation with standard comment bars

**BashFX Standard Patterns Implemented**:
- **Simple stderr**: Inline logging functions (`info`, `okay`, `warn`, `error`, `fatal`, `trace`)
- **QUIET Compliance**: Hierarchical message visibility (`-d`, `-t`, `-q` flags)
- **Guard Functions**: State validation patterns (`_validate_domain`, `_is_notify_configured`)
- **Literal Functions**: Single-purpose, low-level operations (`__whois_query`, `__send_email`)
- **Predictable Helpers**: Consistent helper patterns (`_load_*`, `_get_*`, `_format_*`)

**Deviations from Base Implementation**:
- **Global Execution → Structured Flow**: Original ran in global scope; BashFX version uses proper `main "$@"` invocation
- **Inline Parsing → Dedicated `options()`**: Argument parsing extracted to independent function
- **Flat Functions → Ordinal Hierarchy**: Functions reorganized by responsibility level and call patterns
- **Raw Output → stderr Logging**: All user messages converted to structured logging with quiet mode support
- **Hardcoded Logic → Extensible Registry**: TLD handling converted from switch statement to configurable associative arrays

**Benefits**:
- Consistent user experience across BashFX ecosystem tools
- Maintainable and extensible codebase following established patterns
- Integration capability with larger BashFX framework and utilities
- Predictable debugging and development workflow
- Standard testing and validation approaches

## Enhanced Features Beyond Base Implementation

### 🆕 **New Capabilities vs. Original watchdom**

**Architectural Enhancements**:
- **Command Dispatch System**: Added explicit command routing (`watch`, `time`, `list_tlds`, `add_tld`, `test_tld`) vs. single-function operation
- **Extensible TLD Registry**: Configurable TLD support via `~/.watchdomrc` vs. hardcoded .com/.net/.org only
- **Phase-Aware Polling**: Intelligent 4-phase system (PRE/HEAT/GRACE/COOL) vs. simple ramping (>30m/≤30m/≤5m)
- **Progressive Cooldown**: Gradual interval increase after grace period vs. indefinite 10s polling
- **Email Notification System**: Automated alerts for critical events vs. manual monitoring only
- **Enhanced Time Management**: Standalone time countdown mode vs. domain-only operation

**User Experience Improvements**:
- **Visual Phase Indicators**: Color-coded glyphs and labels (λ, ▲, △, ❄) vs. basic color text
- **Structured Logging**: Hierarchical message levels with quiet mode vs. raw echo statements  
- **Grace Period Management**: User intervention prompts after 3hr threshold vs. indefinite running
- **TLD Management Tools**: Commands to list, add, and test TLD configurations vs. static support
- **Cross-Platform Compatibility**: Enhanced date parsing for GNU/BSD systems vs. basic date usage

**Operational Enhancements**:
- **Resource Conservation**: Intelligent cooldown prevents indefinite aggressive polling
- **Unattended Operation**: Email notifications enable long-term monitoring without human oversight
- **Configuration Validation**: TLD pattern testing and error reporting vs. silent failures
- **Backward Compatibility**: All original command patterns preserved while adding new capabilities
- **Future Extensibility**: Plugin-like TLD system allows community-driven expansion

**Enterprise-Grade Features**:
- **Audit Trail**: Email notifications provide event logging for compliance and tracking
- **Multi-Backend Support**: Email system supports mutt, msmtp, sendmail for different environments
- **Graceful Degradation**: System continues operation even when optional features (email) fail
- **Standard Exit Codes**: Proper automation integration vs. basic success/failure indication

### 📊 **Logging & Observability**
- `info`: General operational messages
- `okay`: Success confirmations  
- `warn`: Non-fatal issues and warnings
- `error`: Recoverable errors
- `fatal`: Unrecoverable errors (exits)
- `trace`: Verbose debugging information

**Quiet Mode Compliance**:
- Default: Only `error`/`fatal` visible
- `-d`: Enable informational messages
- `-t`: Enable trace-level debugging
- `-q`: Force complete silence

### 🔧 **Command Interface**

**Primary Commands**:
```bash
watchdom watch DOMAIN [options]        # Core monitoring functionality
watchdom time "DATETIME" [options]     # Standalone time countdown  
watchdom list_tlds                     # TLD registry management
watchdom add_tld TLD SERVER PATTERN    # Extend TLD support
watchdom test_tld TLD DOMAIN           # Validate configurations
```

**Legacy Compatibility**:
```bash
watchdom DOMAIN [options]              # Auto-routes to 'watch'
watchdom --time_until "DATETIME"       # Auto-routes to 'time'
```

## User Stories & Acceptance Criteria

### 📈 **Epic: Intelligent Domain Monitoring**

**Story**: As a domain investor, I want to monitor domain availability with optimal timing so that I maximize my chance of successful registration while minimizing system resource usage.

**Acceptance Criteria**:
- ✅ System adjusts polling frequency based on target proximity
- ✅ Visual feedback clearly indicates current monitoring phase
- ✅ Resource usage scales appropriately with time sensitivity
- ✅ Monitoring continues unattended until success or user intervention

### 🌍 **Epic: Universal TLD Support**

**Story**: As a brand protection specialist, I want to monitor domains across any TLD so that I can protect trademarks in emerging markets and country-specific extensions.

**Acceptance Criteria**:
- ✅ Built-in support for major TLDs (.com, .net, .org)
- ✅ User can add custom TLD configurations via config file or CLI
- ✅ System validates TLD configurations before monitoring
- ✅ Clear error messages for unsupported TLDs with guidance for adding support

### 📱 **Epic: Automated Notifications**

**Story**: As a busy professional, I want to receive email notifications for critical domain events so that I can respond promptly without constantly monitoring the system.

**Acceptance Criteria**:
- ✅ Email notifications sent for domain availability, target time reached, and grace period exceeded
- ✅ Notifications include relevant context and timestamps
- ✅ System continues monitoring if email delivery fails
- ✅ Multiple email backend support for different environments

### ⏰ **Epic: Advanced Time Management**

**Story**: As a legal professional tracking domain dispute deadlines, I want flexible time input and display options so that I can work across different time zones and coordinate with international teams.

**Acceptance Criteria**:
- ✅ Accepts multiple datetime formats (ISO, epoch, natural language)
- ✅ Displays time in both UTC and local formats
- ✅ Provides standalone time countdown functionality
- ✅ Handles cross-platform date parsing differences

## Success Metrics

### 📊 **Technical Metrics**
- **Accuracy**: >99% domain state detection accuracy
- **Performance**: <2s startup time, <100MB memory usage
- **Reliability**: 99.9% uptime during monitoring sessions
- **Compatibility**: Support for 95% of Unix-like systems

### 👥 **User Metrics**  
- **Adoption**: Integration into 3+ major domain workflow tools
- **Satisfaction**: <10s learning curve for basic usage
- **Retention**: 80% of users continue using after 30 days
- **Support**: <5% of sessions require documentation lookup

### 🎯 **Business Metrics**
- **Efficiency**: 50% reduction in manual domain checking time
- **Success Rate**: 25% improvement in successful domain acquisitions
- **Cost Savings**: $0 recurring fees vs. SaaS alternatives
- **Extensibility**: Community contributions of 10+ additional TLD configurations

## Implementation Roadmap

### 🚀 **Phase 1: Core Infrastructure** (Milestone 1)
- ✅ BashFX architectural compliance
- ✅ Basic stderr logging system
- ✅ Standard command interface (`main`, `dispatch`, `options`)
- ✅ Backward compatibility preservation

**Deliverable**: Functionally equivalent to original script with improved architecture

### 🎨 **Phase 2: Intelligent Polling** (Milestone 2)  
- ✅ Phase detection system (PRE/HEAT/GRACE/COOL)
- ✅ Dynamic interval calculation
- ✅ Visual feedback with phase-specific styling
- ✅ Progressive cooldown algorithms

**Deliverable**: Smart polling system with resource-conscious behavior

### 🌐 **Phase 3: TLD Extensibility** (Milestone 3)
- ✅ Configurable TLD registry system
- ✅ User configuration file support (`~/.watchdomrc`)
- ✅ TLD management commands (`list_tlds`, `add_tld`, `test_tld`)
- ✅ Runtime TLD validation

**Deliverable**: Universal TLD support with user extensibility

### 📧 **Phase 4: Notification System** (Milestone 4)
- ✅ Email notification framework
- ✅ Multiple email backend support
- ✅ Event-driven notification triggers
- ✅ Configuration validation and graceful degradation

**Deliverable**: Automated notification system for unattended monitoring

### ⏰ **Phase 5: Enhanced Time Management** (Milestone 5)
- ✅ Advanced datetime parsing
- ✅ Standalone time countdown mode
- ✅ Grace period management with user intervention
- ✅ Cross-platform time handling compatibility

**Deliverable**: Comprehensive time management and deadline tracking

### 🔧 **Phase 6: Polish & Optimization** (Milestone 6)
- ✅ Comprehensive error handling and validation
- ✅ Performance optimization and resource monitoring
- ✅ Documentation and usage examples
- ✅ Community feedback integration

**Deliverable**: Production-ready domain monitoring solution

## Risk Assessment & Mitigation

### ⚠️ **Technical Risks**

**Risk**: Whois server rate limiting or blocking  
**Impact**: High - Core functionality failure  
**Mitigation**: Intelligent interval adjustment, configurable minimums, multiple fallback strategies

**Risk**: Cross-platform compatibility issues  
**Impact**: Medium - Reduced user base  
**Mitigation**: Extensive testing on GNU/BSD systems, fallback implementations for date parsing

**Risk**: Email delivery reliability  
**Impact**: Low - Graceful degradation implemented  
**Mitigation**: Multiple email backend support, non-blocking operation, clear error reporting

### 📋 **Product Risks**

**Risk**: User adoption barriers due to complexity  
**Impact**: Medium - Limited market penetration  
**Mitigation**: Backward compatibility, comprehensive documentation, intuitive defaults

**Risk**: TLD providers changing whois response formats  
**Impact**: Medium - Requires ongoing maintenance  
**Mitigation**: User-configurable patterns, community-driven configuration sharing, test validation tools

## Competitive Analysis

### 🏆 **Competitive Advantages**
- **Cost**: Free, open-source vs. expensive SaaS solutions
- **Intelligence**: Phase-aware polling vs. static interval monitoring  
- **Extensibility**: Universal TLD support vs. limited provider coverage
- **Integration**: CLI-native vs. web-only interfaces
- **Privacy**: Self-hosted vs. data sharing with third parties

### 📊 **Market Position**
- **Primary Competitors**: DomainTools, DropCatch, NameJet monitoring
- **Secondary Competitors**: Custom scripts, manual monitoring
- **Differentiation**: Intelligent resource usage + extensible architecture + notification system

## Future Considerations

### 🔮 **Potential Enhancements**
- **Multi-domain monitoring**: Parallel monitoring of domain lists
- **Pattern learning**: Automatic detection of TLD availability patterns  
- **Integration APIs**: REST interface for web application integration
- **Distributed monitoring**: Coordination across multiple monitoring nodes
- **Advanced notifications**: Slack, Discord, webhook support

### 🎯 **Success Criteria for v3.0**
- Community-driven TLD configuration repository
- Integration with major domain registration APIs
- Real-time collaboration features for team monitoring
- Advanced analytics and reporting capabilities

---

**Document Version**: 1.0  
**Last Updated**: August 15, 2025  
**Next Review**: September 15, 2025  
**Status**: ✅ **COMPLETE** - All requirements implemented and delivered