## ADDED Requirements

### Requirement: Case results are sorted by file type in Markdown export

The system SHALL sort case results by file type when exporting Plan reports to Markdown format. The sorting shall be based on the file extension extracted from the case name.

#### Scenario: Sort cases by file type in summary table
- **WHEN** user exports a Plan report to Markdown format
- **THEN** the "案例结果总结" (Case Results Summary) table displays cases sorted by file type

#### Scenario: Sort cases by file type in detailed results
- **WHEN** user exports a Plan report to Markdown format  
- **THEN** the "各案例详细结果" (Detailed Case Results) section displays cases in the same order as the summary table

#### Scenario: File type extraction from case name
- **WHEN** extracting file type from case name (e.g., `Controller.java` → `java`)
- **THEN** the system extracts the extension after the last dot and converts to lowercase

#### Scenario: Cases without extension sorted last
- **WHEN** a case name has no file extension
- **THEN** that case is placed in a special "unknown" group and sorted after all known types

#### Scenario: Same type sorted alphabetically
- **WHEN** multiple cases have the same file type
- **THEN** they are sorted alphabetically by case name within that type

#### Scenario: Type groups sorted alphabetically
- **WHEN** multiple file types exist (e.g., java, sql, py)
- **THEN** the type groups are sorted alphabetically by type name (java < py < sql)
