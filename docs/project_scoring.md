# Project Scoring

Projects have two independent scores: a general popularity score and a science score.

## Popularity Score

The popularity score measures a project's reach and adoption. It sums five component scores, each calculated using a logarithmic scale to prevent extremely popular projects from dominating. See the [`update_score`](../app/models/project.rb#L1105) method.

```
score = repository_score + packages_score + commits_score + dependencies_score + events_score
```

The component scores are defined in [`score_parts`](../app/models/project.rb#L1127):

**Repository score** ([`repository_score`](../app/models/project.rb#L1137)): `log(stargazers_count + open_issues_count)`

**Packages score** ([`packages_score`](../app/models/project.rb#L1145)): `log(downloads + dependent_packages_count + dependent_repos_count + docker_downloads_count + docker_dependents_count + unique_maintainers)`

**Commits score** ([`commits_score`](../app/models/project.rb#L1157)): `log(total_committers)`

**Dependencies score** ([`dependencies_score`](../app/models/project.rb#L1164)): Reserved for future use (currently 0)

**Events score** ([`events_score`](../app/models/project.rb#L1169)): Reserved for future use (currently 0)

The logarithmic scaling means that going from 10 to 100 stars adds roughly the same amount to the score as going from 1,000 to 10,000.

## Science Score

The science score measures how well a project follows academic software practices. It ranges from 0 to 100 and is calculated by [`ScienceScoreCalculator`](../app/services/science_score_calculator.rb).

The Project model calls this via [`update_science_score`](../app/models/project.rb#L1109), which persists both the score and a detailed breakdown to the database.

Two [scopes](../app/models/project.rb#L50-L51) filter projects by science score:
- `scientific`: score >= 20
- `highly_scientific`: score >= 75

### JOSS-Published Projects

Projects with JOSS metadata receive a base score of 85, with up to 15 additional points from bonus indicators. This logic is in [`calculate_score`](../app/services/science_score_calculator.rb#L95).

| Indicator | Bonus |
|-----------|-------|
| CITATION.cff file | 5 |
| codemeta.json file | 3 |
| .zenodo.json file | 3 |
| DOI in README | 2 |
| Academic committers | 2 |
| Institutional owner | 3 |

### Non-JOSS Projects

Projects without JOSS publication are scored by weighting seven indicators (see [`scoring_weights`](../app/services/science_score_calculator.rb#L124)):

| Indicator | Weight |
|-----------|--------|
| CITATION.cff file | 22% |
| DOI in README | 17% |
| codemeta.json file | 13% |
| .zenodo.json file | 13% |
| Academic publication links | 13% |
| Academic committers | 13% |
| Institutional owner | 9% |

The final score is the sum of weights for present indicators, normalized to a percentage.

### Indicator Details

Each indicator is checked by a method in `ScienceScoreCalculator`:

**CITATION.cff file** ([`check_citation_file`](../app/services/science_score_calculator.rb#L153)): The project has a CITATION.cff file, which tells others how to cite the software.

**codemeta.json file** ([`check_codemeta_file`](../app/services/science_score_calculator.rb#L161)): The project has a codemeta.json file providing machine-readable software metadata. Detected by checking the repository metadata files.

**.zenodo.json file** ([`check_zenodo_file`](../app/services/science_score_calculator.rb#L179)): The project has Zenodo integration configured for archiving releases.

**DOI in README** ([`check_doi_in_readme`](../app/services/science_score_calculator.rb#L197)): The README contains DOI references matching patterns like `10.xxxx/...` or links to doi.org. The patterns are defined in [`DOI_PATTERNS`](../app/services/science_score_calculator.rb#L41).

**Academic publication links** ([`check_academic_links`](../app/services/science_score_calculator.rb#L236)): The README links to academic sites. The [`ACADEMIC_LINK_PATTERNS`](../app/services/science_score_calculator.rb#L47) constant includes arXiv, bioRxiv, PubMed, Nature, Science, IEEE, ACM, PLOS, Springer, Wiley, Zenodo, and others.

**Academic committers** ([`check_academic_committers`](../app/services/science_score_calculator.rb#L256)): At least one committer has an email from an academic domain. The [`ACADEMIC_DOMAINS`](../app/services/science_score_calculator.rb#L4) constant includes .edu, .ac.uk, university research labs, national laboratories (NASA, NIH, NIST, ORNL, etc.), and major research institutions (CERN, Max Planck, Fraunhofer, INRIA, etc.).

**Institutional owner** ([`check_institutional_owner`](../app/services/science_score_calculator.rb#L288)): The repository owner is an organization with a website on an academic domain. Only applies to organization-owned repositories, not personal accounts.

**JOSS paper** ([`check_joss_paper`](../app/services/science_score_calculator.rb#L320)): The project has been published in the Journal of Open Source Software. Detected via the `joss_metadata` field on the project.

### Score Ranges

- 0-20: Low scientific indicators
- 20-40: Some scientific practices
- 40-60: Moderate scientific practices
- 60-80: Strong scientific practices
- 80-100: Excellent scientific practices (typically JOSS-published or equivalent)
