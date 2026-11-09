// Mock data for Browse Articles. Verified against script.sql (Article + Edition + Writes + Author).
// `year` comes from Edition.PubYear; authors are ordered by Writes.Position.
window.MOCK_ARTICLES = [
  {
    "id": "AR001",
    "title": "Adaptive Indexing for Large-Scale Relational Workloads",
    "authors": [
      {
        "id": "AU001",
        "name": "Nguyen Van An"
      },
      {
        "id": "AU002",
        "name": "Tran Thi Binh"
      }
    ],
    "year": 2016
  },
  {
    "id": "AR002",
    "title": "Cost-Based Query Optimization Under Uncertainty",
    "authors": [
      {
        "id": "AU001",
        "name": "Nguyen Van An"
      },
      {
        "id": "AU016",
        "name": "Jamal Williams"
      },
      {
        "id": "AU028",
        "name": "Victor Dubois"
      },
      {
        "id": "AU002",
        "name": "Tran Thi Binh"
      }
    ],
    "year": 2020
  },
  {
    "id": "AR003",
    "title": "Snapshot Isolation Revisited for Distributed Transactions",
    "authors": [
      {
        "id": "AU001",
        "name": "Nguyen Van An"
      },
      {
        "id": "AU002",
        "name": "Tran Thi Binh"
      }
    ],
    "year": 2018
  },
  {
    "id": "AR004",
    "title": "A Survey of Graph Database Engines",
    "authors": [
      {
        "id": "AU026",
        "name": "Takumi Sato"
      },
      {
        "id": "AU025",
        "name": "Sofia Alvarez"
      },
      {
        "id": "AU028",
        "name": "Victor Dubois"
      }
    ],
    "year": 2022
  },
  {
    "id": "AR005",
    "title": "Deep Residual Models for Medical Image Classification",
    "authors": [
      {
        "id": "AU016",
        "name": "Jamal Williams"
      },
      {
        "id": "AU013",
        "name": "Grace Kim"
      },
      {
        "id": "AU001",
        "name": "Nguyen Van An"
      }
    ],
    "year": 2020
  },
  {
    "id": "AR006",
    "title": "Attention Mechanisms in Document Retrieval",
    "authors": [
      {
        "id": "AU028",
        "name": "Victor Dubois"
      },
      {
        "id": "AU014",
        "name": "Hiroshi Tanaka"
      }
    ],
    "year": 2019
  },
  {
    "id": "AR007",
    "title": "Learning to Rank with Click Feedback",
    "authors": [
      {
        "id": "AU016",
        "name": "Jamal Williams"
      },
      {
        "id": "AU017",
        "name": "Kavita Rao"
      },
      {
        "id": "AU026",
        "name": "Takumi Sato"
      }
    ],
    "year": 2017
  },
  {
    "id": "AR008",
    "title": "Scalable Collaborative Filtering with Implicit Signals",
    "authors": [
      {
        "id": "AU019",
        "name": "Maria Gonzalez"
      }
    ],
    "year": 2021
  },
  {
    "id": "AR009",
    "title": "Knowledge Graph Embeddings for Entity Linking",
    "authors": [
      {
        "id": "AU025",
        "name": "Sofia Alvarez"
      },
      {
        "id": "AU005",
        "name": "Vo Thi Hoa"
      }
    ],
    "year": 2019
  },
  {
    "id": "AR010",
    "title": "Benchmarking NoSQL Stores on Mixed Workloads",
    "authors": [
      {
        "id": "AU023",
        "name": "Quang Dang"
      }
    ],
    "year": 2023
  },
  {
    "id": "AR011",
    "title": "Differential Privacy in Query Processing",
    "authors": [
      {
        "id": "AU022",
        "name": "Priya Sharma"
      },
      {
        "id": "AU004",
        "name": "Pham Minh Duc"
      },
      {
        "id": "AU023",
        "name": "Quang Dang"
      }
    ],
    "year": 2016
  },
  {
    "id": "AR012",
    "title": "Policy Gradient Methods for Index Selection",
    "authors": [
      {
        "id": "AU014",
        "name": "Hiroshi Tanaka"
      },
      {
        "id": "AU016",
        "name": "Jamal Williams"
      },
      {
        "id": "AU005",
        "name": "Vo Thi Hoa"
      }
    ],
    "year": 2020
  },
  {
    "id": "AR013",
    "title": "Transformer Language Models for Sentiment Analysis",
    "authors": [
      {
        "id": "AU008",
        "name": "Bob Martinez"
      },
      {
        "id": "AU028",
        "name": "Victor Dubois"
      },
      {
        "id": "AU004",
        "name": "Pham Minh Duc"
      }
    ],
    "year": 2018
  },
  {
    "id": "AR014",
    "title": "Clustering Citation Networks at Scale",
    "authors": [
      {
        "id": "AU023",
        "name": "Quang Dang"
      },
      {
        "id": "AU015",
        "name": "Ingrid Larsen"
      },
      {
        "id": "AU022",
        "name": "Priya Sharma"
      },
      {
        "id": "AU016",
        "name": "Jamal Williams"
      }
    ],
    "year": 2022
  },
  {
    "id": "AR015",
    "title": "Open Access and Citation Advantage: An Empirical Study",
    "authors": [
      {
        "id": "AU018",
        "name": "Lars Becker"
      },
      {
        "id": "AU009",
        "name": "Chen Wei"
      },
      {
        "id": "AU013",
        "name": "Grace Kim"
      },
      {
        "id": "AU022",
        "name": "Priya Sharma"
      }
    ],
    "year": 2020
  },
  {
    "id": "AR016",
    "title": "Genome Sequence Alignment on Columnar Stores",
    "authors": [
      {
        "id": "AU018",
        "name": "Lars Becker"
      },
      {
        "id": "AU026",
        "name": "Takumi Sato"
      }
    ],
    "year": 2019
  },
  {
    "id": "AR017",
    "title": "Entity Resolution for Bibliographic Databases",
    "authors": [
      {
        "id": "AU017",
        "name": "Kavita Rao"
      },
      {
        "id": "AU023",
        "name": "Quang Dang"
      },
      {
        "id": "AU016",
        "name": "Jamal Williams"
      },
      {
        "id": "AU026",
        "name": "Takumi Sato"
      }
    ],
    "year": 2017
  },
  {
    "id": "AR018",
    "title": "Learned Cardinality Estimation",
    "authors": [
      {
        "id": "AU014",
        "name": "Hiroshi Tanaka"
      },
      {
        "id": "AU007",
        "name": "Alice Johnson"
      },
      {
        "id": "AU010",
        "name": "Daniela Rossi"
      }
    ],
    "year": 2021
  },
  {
    "id": "AR019",
    "title": "Federated Learning for Recommender Systems",
    "authors": [
      {
        "id": "AU001",
        "name": "Nguyen Van An"
      },
      {
        "id": "AU002",
        "name": "Tran Thi Binh"
      }
    ],
    "year": 2019
  },
  {
    "id": "AR020",
    "title": "Ontology-Based Data Integration of Scholarly Metadata",
    "authors": [
      {
        "id": "AU021",
        "name": "Olivia Brown"
      },
      {
        "id": "AU020",
        "name": "Noah Fischer"
      }
    ],
    "year": 2023
  },
  {
    "id": "AR021",
    "title": "Temporal Query Languages for Evolving Affiliations",
    "authors": [
      {
        "id": "AU026",
        "name": "Takumi Sato"
      },
      {
        "id": "AU017",
        "name": "Kavita Rao"
      },
      {
        "id": "AU016",
        "name": "Jamal Williams"
      }
    ],
    "year": 2016
  },
  {
    "id": "AR022",
    "title": "Contrastive Pretraining for Scientific Text",
    "authors": [
      {
        "id": "AU007",
        "name": "Alice Johnson"
      },
      {
        "id": "AU009",
        "name": "Chen Wei"
      }
    ],
    "year": 2020
  },
  {
    "id": "AR023",
    "title": "Frequent Pattern Mining in Co-authorship Graphs",
    "authors": [
      {
        "id": "AU016",
        "name": "Jamal Williams"
      },
      {
        "id": "AU015",
        "name": "Ingrid Larsen"
      },
      {
        "id": "AU017",
        "name": "Kavita Rao"
      },
      {
        "id": "AU025",
        "name": "Sofia Alvarez"
      }
    ],
    "year": 2018
  },
  {
    "id": "AR024",
    "title": "Convolutional Architectures for Figure Retrieval",
    "authors": [
      {
        "id": "AU026",
        "name": "Takumi Sato"
      },
      {
        "id": "AU014",
        "name": "Hiroshi Tanaka"
      },
      {
        "id": "AU018",
        "name": "Lars Becker"
      }
    ],
    "year": 2022
  },
  {
    "id": "AR025",
    "title": "Multi-Version Concurrency Control in Practice",
    "authors": [
      {
        "id": "AU002",
        "name": "Tran Thi Binh"
      },
      {
        "id": "AU027",
        "name": "Uyen Do"
      },
      {
        "id": "AU010",
        "name": "Daniela Rossi"
      },
      {
        "id": "AU011",
        "name": "Elena Petrova"
      }
    ],
    "year": 2020
  },
  {
    "id": "AR026",
    "title": "Keyword Extraction from Abstracts with Transformers",
    "authors": [
      {
        "id": "AU026",
        "name": "Takumi Sato"
      },
      {
        "id": "AU004",
        "name": "Pham Minh Duc"
      },
      {
        "id": "AU015",
        "name": "Ingrid Larsen"
      }
    ],
    "year": 2019
  },
  {
    "id": "AR027",
    "title": "Link Prediction on Citation Graphs",
    "authors": [
      {
        "id": "AU023",
        "name": "Quang Dang"
      },
      {
        "id": "AU026",
        "name": "Takumi Sato"
      },
      {
        "id": "AU017",
        "name": "Kavita Rao"
      },
      {
        "id": "AU009",
        "name": "Chen Wei"
      }
    ],
    "year": 2017
  },
  {
    "id": "AR028",
    "title": "Join Ordering with Reinforcement Learning",
    "authors": [
      {
        "id": "AU006",
        "name": "Huynh Quoc Khanh"
      },
      {
        "id": "AU014",
        "name": "Hiroshi Tanaka"
      },
      {
        "id": "AU027",
        "name": "Uyen Do"
      }
    ],
    "year": 2021
  },
  {
    "id": "AR029",
    "title": "Reproducibility in Machine Learning Research",
    "authors": [
      {
        "id": "AU016",
        "name": "Jamal Williams"
      },
      {
        "id": "AU003",
        "name": "Le Hoang Cuong"
      },
      {
        "id": "AU021",
        "name": "Olivia Brown"
      },
      {
        "id": "AU009",
        "name": "Chen Wei"
      }
    ],
    "year": 2019
  },
  {
    "id": "AR030",
    "title": "Efficient Top-k Retrieval over Inverted Indexes",
    "authors": [
      {
        "id": "AU012",
        "name": "Farid Haddad"
      },
      {
        "id": "AU004",
        "name": "Pham Minh Duc"
      },
      {
        "id": "AU007",
        "name": "Alice Johnson"
      }
    ],
    "year": 2023
  },
  {
    "id": "AR031",
    "title": "Protein Function Prediction with Graph Networks",
    "authors": [
      {
        "id": "AU028",
        "name": "Victor Dubois"
      },
      {
        "id": "AU014",
        "name": "Hiroshi Tanaka"
      },
      {
        "id": "AU005",
        "name": "Vo Thi Hoa"
      },
      {
        "id": "AU015",
        "name": "Ingrid Larsen"
      }
    ],
    "year": 2016
  },
  {
    "id": "AR032",
    "title": "Detecting Paper Mill Articles with Text Mining",
    "authors": [
      {
        "id": "AU003",
        "name": "Le Hoang Cuong"
      }
    ],
    "year": 2020
  },
  {
    "id": "AR033",
    "title": "Schema Matching with Pretrained Language Models",
    "authors": [
      {
        "id": "AU015",
        "name": "Ingrid Larsen"
      }
    ],
    "year": 2018
  },
  {
    "id": "AR034",
    "title": "Explainable Recommendation via Knowledge Graphs",
    "authors": [
      {
        "id": "AU018",
        "name": "Lars Becker"
      },
      {
        "id": "AU027",
        "name": "Uyen Do"
      },
      {
        "id": "AU003",
        "name": "Le Hoang Cuong"
      }
    ],
    "year": 2022
  },
  {
    "id": "AR035",
    "title": "Scalable Graph Clustering with Spark",
    "authors": [
      {
        "id": "AU026",
        "name": "Takumi Sato"
      },
      {
        "id": "AU007",
        "name": "Alice Johnson"
      },
      {
        "id": "AU008",
        "name": "Bob Martinez"
      }
    ],
    "year": 2020
  },
  {
    "id": "AR036",
    "title": "Read-Optimized Storage for Citation Data",
    "authors": [
      {
        "id": "AU020",
        "name": "Noah Fischer"
      }
    ],
    "year": 2019
  },
  {
    "id": "AR037",
    "title": "Zero-Shot Subject Classification of Articles",
    "authors": [
      {
        "id": "AU025",
        "name": "Sofia Alvarez"
      }
    ],
    "year": 2017
  },
  {
    "id": "AR038",
    "title": "Bias in Peer Review: A Citation-Based Analysis",
    "authors": [
      {
        "id": "AU009",
        "name": "Chen Wei"
      },
      {
        "id": "AU022",
        "name": "Priya Sharma"
      },
      {
        "id": "AU025",
        "name": "Sofia Alvarez"
      }
    ],
    "year": 2021
  },
  {
    "id": "AR039",
    "title": "Streaming Joins over Bibliographic Feeds",
    "authors": [
      {
        "id": "AU012",
        "name": "Farid Haddad"
      },
      {
        "id": "AU005",
        "name": "Vo Thi Hoa"
      },
      {
        "id": "AU001",
        "name": "Nguyen Van An"
      },
      {
        "id": "AU011",
        "name": "Elena Petrova"
      }
    ],
    "year": 2019
  },
  {
    "id": "AR040",
    "title": "Self-Supervised Learning for Scientific Image Search",
    "authors": [
      {
        "id": "AU019",
        "name": "Maria Gonzalez"
      },
      {
        "id": "AU025",
        "name": "Sofia Alvarez"
      },
      {
        "id": "AU028",
        "name": "Victor Dubois"
      },
      {
        "id": "AU016",
        "name": "Jamal Williams"
      }
    ],
    "year": 2023
  }
];
