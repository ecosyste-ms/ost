class ScienceScoreCalculator
  attr_reader :project, :breakdown

  ACADEMIC_DOMAINS = [
    'edu', 'ac.uk', 'edu.au', 'edu.cn', 'edu.br', 'edu.mx', 'edu.ar',
    'edu.co', 'edu.in', 'ac.jp', 'ac.za', 'edu.sg', 'edu.hk', 'edu.my',
    'edu.ph', 'edu.tw', 'edu.eg', 'edu.pk', 'edu.vn', 'edu.tr',
    'univ', 'university', 'college', 'institute', 'academia',
    # French academic institutions
    'umontpellier.fr', 'sorbonne', 'cnrs.fr', 'inria.fr', 'inserm.fr',
    'pasteur.fr', 'polytechnique', 'centralesupelec.fr', 'ens.fr',
    'univ-', 'u-', # Common French university prefixes
    # German academic institutions
    'mpg.de', 'fraunhofer.de', 'helmholtz', 'uni-', 'tu-', 'fh-',
    'dlr.de', 'fz-juelich.de', 'tum.de', 'rwth-aachen.de', 'dfki.de',
    # Netherlands
    'tudelft.nl', 'uva.nl', 'vu.nl', 'rug.nl', 'tue.nl', 'leiden',
    # Swiss
    'ethz.ch', 'epfl.ch', 'cern.ch', 'unige.ch', 'unibas.ch', 'psi.ch',
    # Austrian
    'ac.at', 'tuwien.ac.at', 'uibk.ac.at',
    # Israeli
    'ac.il', 'huji.ac.il', 'weizmann.ac.il', 'technion.ac.il',
    # Indian IITs and research
    'ac.in', 'iitb.ac.in', 'iiitd.ac.in', 'iitk.ac.in', 'iisc.ac.in',
    # Other European
    'embl', 'ebi.ac.uk', 'ku.dk', 'dtu.dk', 'kth.se', 'chalmers.se',
    'ntnu.no', 'uio.no', 'ucl.ac.uk', 'cam.ac.uk', 'ox.ac.uk', 'ic.ac.uk',
    # Canadian
    'utoronto.ca', 'ubc.ca', 'mcgill.ca', 'uwaterloo.ca', 'ualberta.ca',
    # Australian/NZ
    'csiro.au', 'unsw.edu.au', 'anu.edu.au', 'unimelb.edu.au',
    # US National Labs and Research
    'nih.gov', 'nasa.gov', 'noaa.gov', 'usgs.gov', 'nist.gov',
    'ornl.gov', 'lbl.gov', 'anl.gov', 'bnl.gov', 'fnal.gov',
    'lanl.gov', 'llnl.gov', 'pnnl.gov', 'inl.gov',
    # Research organizations
    'ligo.org', 'ieee.org'
  ]

  DOI_PATTERNS = [
    %r{10\.\d{4,}/[-._;()/:\w]+},
    %r{doi\.org/10\.\d{4,}},
    %r{dx\.doi\.org/10\.\d{4,}}
  ]

  ACADEMIC_LINK_PATTERNS = [
    %r{arxiv\.org},
    %r{biorxiv\.org},
    %r{medrxiv\.org},
    %r{preprints\.org},
    %r{researchgate\.net},
    %r{academia\.edu},
    %r{scholar\.google},
    %r{pubmed\.ncbi},
    %r{ncbi\.nlm\.nih\.gov},
    %r{sciencedirect\.com},
    %r{springer\.com},
    %r{wiley\.com},
    %r{nature\.com},
    %r{science\.org},
    %r{plos\.org},
    %r{frontiersin\.org},
    %r{mdpi\.com},
    %r{ieee\.org},
    %r{acm\.org},
    %r{aps\.org},
    %r{iop\.org},
    %r{rsc\.org},
    %r{acs\.org},
    %r{joss\.theoj\.org},
    %r{zenodo\.org}
  ]

  def initialize(project)
    @project = project
    @breakdown = {}
  end

  def calculate
    @breakdown = {
      has_citation_file: check_citation_file,
      has_codemeta: check_codemeta_file,
      has_zenodo: check_zenodo_file,
      has_doi_in_readme: check_doi_in_readme,
      has_academic_links: check_academic_links,
      has_academic_committers: check_academic_committers,
      has_institutional_owner: check_institutional_owner,
      has_joss_paper: check_joss_paper
    }

    calculate_score
  end

  def calculate_score
    # JOSS projects are automatically scientific (peer-reviewed)
    if project.joss_metadata.present?
      # JOSS projects get base 85% plus any additional indicators
      base_score = 85.0
      bonus_weight = 0.0

      # Add bonuses for additional scientific indicators (up to 15%)
      bonus_weights = {
        has_citation_file: 0.05,
        has_codemeta: 0.03,
        has_zenodo: 0.03,
        has_doi_in_readme: 0.02,
        has_academic_committers: 0.02,
        has_institutional_owner: 0.03
      }

      @breakdown.each do |key, value|
        if value[:present] && bonus_weights[key]
          bonus_weight += bonus_weights[key]
        end
      end

      final_score = base_score + (bonus_weight * 100)
    else
      # Non-JOSS projects use weighted scoring
      total_weight = 0.0
      weighted_score = 0.0

      scoring_weights = {
        has_citation_file: 0.22,
        has_codemeta: 0.13,
        has_zenodo: 0.13,
        has_doi_in_readme: 0.17,
        has_academic_links: 0.13,
        has_academic_committers: 0.13,
        has_institutional_owner: 0.09
      }

      @breakdown.each do |key, value|
        if value[:present] && key != :has_joss_paper
          weight = scoring_weights[key] || 0
          weighted_score += weight
          total_weight += weight
        end
      end

      # Normalize to percentage
      final_score = scoring_weights.values.sum > 0 ? (weighted_score / scoring_weights.values.sum) * 100 : 0
    end

    {
      score: [final_score.round(2), 100.0].min,
      breakdown: @breakdown,
      max_score: 100
    }
  end

  def check_citation_file
    {
      present: project.citation_file.present?,
      description: "CITATION.cff file",
      details: project.citation_file.present? ? "Found CITATION.cff file" : nil
    }
  end

  def check_codemeta_file
    has_codemeta = false

    if project.repository.present? &&
       project.repository['metadata'].present? &&
       project.repository['metadata']['files'].present?

      files = project.repository['metadata']['files']
      has_codemeta = files.keys.any? { |k| k.to_s.downcase.include?('codemeta') }
    end

    {
      present: has_codemeta,
      description: "codemeta.json file",
      details: has_codemeta ? "Found codemeta.json file" : nil
    }
  end

  def check_zenodo_file
    has_zenodo = false

    if project.repository.present? &&
       project.repository['metadata'].present? &&
       project.repository['metadata']['files'].present?

      files = project.repository['metadata']['files']
      has_zenodo = files.keys.any? { |k| k.to_s.downcase.include?('zenodo') }
    end

    {
      present: has_zenodo,
      description: ".zenodo.json file",
      details: has_zenodo ? "Found .zenodo.json file" : nil
    }
  end

  def check_doi_in_readme
    has_doi = false
    doi_count = 0
    sources = []

    # Check README for DOIs
    if project.readme.present?
      readme_text = project.readme.downcase
      DOI_PATTERNS.each do |pattern|
        matches = readme_text.scan(pattern)
        if matches.any?
          has_doi = true
          doi_count += matches.length
          sources << "README" unless sources.include?("README")
        end
      end
    end

    # Check JOSS metadata for DOI
    if project.joss_metadata.present? && project.joss_metadata['doi']
      has_doi = true
      doi_count += 1
      sources << "JOSS metadata"
    end

    details = if has_doi
      source_text = sources.join(" and ")
      "Found #{doi_count} DOI reference(s) in #{source_text}"
    else
      nil
    end

    {
      present: has_doi,
      description: "DOI references",
      details: details
    }
  end

  def check_academic_links
    return { present: false, description: "Academic links in README", details: nil } unless project.readme.present?

    readme_text = project.readme.downcase
    academic_sites = []

    ACADEMIC_LINK_PATTERNS.each do |pattern|
      if readme_text.match?(pattern)
        site_name = pattern.source.gsub(/\\\./, '.').gsub(/[\\^$]/, '')
        academic_sites << site_name
      end
    end

    {
      present: academic_sites.any?,
      description: "Academic publication links",
      details: academic_sites.any? ? "Links to: #{academic_sites.uniq.join(', ')}" : nil
    }
  end

  def check_academic_committers
    return { present: false, description: "Academic email domains", details: nil } unless project.raw_committers.present?

    academic_committers = []
    total_committers = project.raw_committers.length

    project.raw_committers.each do |committer|
      next unless committer['email'].present?

      email_domain = committer['email'].split('@').last&.downcase
      next unless email_domain

      if ACADEMIC_DOMAINS.any? { |domain| email_domain.include?(domain) }
        academic_committers << {
          name: committer['name'],
          domain: email_domain,
          commits: committer['count']
        }
      end
    end

    percentage = total_committers > 0 ? (academic_committers.length.to_f / total_committers * 100).round(1) : 0

    {
      present: academic_committers.any?,
      description: "Committers with academic emails",
      details: academic_committers.any? ?
        "#{academic_committers.length} of #{total_committers} committers (#{percentage}%) from academic institutions" : nil,
      committers: academic_committers.take(5)
    }
  end

  def check_institutional_owner
    owner_data = project.owner
    return { present: false, description: "Institutional organization owner", details: nil } unless owner_data.present?

    # Check if owner is an organization
    return { present: false, description: "Institutional organization owner", details: nil } unless owner_data['kind'] == 'organization'

    # Check if owner has a website
    return { present: false, description: "Institutional organization owner", details: nil } unless owner_data['website'].present?

    website = owner_data['website'].downcase

    # Extract domain from website URL
    domain = begin
      uri = URI.parse(website.start_with?('http') ? website : "https://#{website}")
      uri.host
    rescue
      website.gsub(/^(https?:\/\/)?(www\.)?/, '').split('/').first
    end

    return { present: false, description: "Institutional organization owner", details: nil } unless domain

    # Check if domain matches any academic patterns
    is_institutional = ACADEMIC_DOMAINS.any? { |academic_domain| domain.include?(academic_domain) }

    {
      present: is_institutional,
      description: "Institutional organization owner",
      details: is_institutional ? "Organization #{owner_data['login']} has institutional domain (#{domain})" : nil
    }
  end

  def check_joss_paper
    {
      present: project.joss_metadata.present?,
      description: "JOSS paper metadata",
      details: project.joss_metadata.present? ? "Published in Journal of Open Source Software" : nil
    }
  end
end
