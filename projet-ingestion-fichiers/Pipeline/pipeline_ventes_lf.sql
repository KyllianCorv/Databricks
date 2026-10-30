-- BRONZE : ingestion des fichiers du Volume (incrémentale)
CREATE OR REFRESH STREAMING TABLE bronze_ventes_lf
AS SELECT
    *,
    _metadata.file_name AS fichier_source,
    current_timestamp() AS charge_le
FROM STREAM read_files(
    '/Volumes/workspace/ventes/depot/',
    format => 'csv',
    header => true
);

-- SILVER : typage, calcul du CA, contrôles de qualité
CREATE OR REFRESH MATERIALIZED VIEW silver_ventes_lf (
    CONSTRAINT id_present   EXPECT (id_vente IS NOT NULL) ON VIOLATION DROP ROW,
    CONSTRAINT quantite_ok  EXPECT (quantite > 0)         ON VIOLATION DROP ROW,
    CONSTRAINT prix_ok      EXPECT (prix_unitaire > 0)    ON VIOLATION DROP ROW
)
AS SELECT
    id_vente,
    CAST(date AS DATE)            AS date,
    magasin,
    produit,
    CAST(quantite AS INT)         AS quantite,
    CAST(prix_unitaire AS DOUBLE) AS prix_unitaire,
    CAST(quantite AS INT) * CAST(prix_unitaire AS DOUBLE) AS chiffre_affaires
FROM bronze_ventes_lf;

-- GOLD : chiffre d'affaires par magasin et par jour
CREATE OR REFRESH MATERIALIZED VIEW gold_ca_jour_lf
AS SELECT
    date,
    magasin,
    COUNT(*)                        AS nb_ventes,
    ROUND(SUM(chiffre_affaires), 2) AS ca_total
FROM silver_ventes_lf
GROUP BY date, magasin;