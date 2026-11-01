// Assina o APK de release com a mesma chave do CI (android/key.properties +
// keystore), em vez da chave de debug que o prebuild coloca por padrão.
// Sem isso o Android recusa instalar a atualização por cima da versão antiga.
const { withAppBuildGradle } = require('expo/config-plugins');

const CABECALHO = `def keystorePropertiesFile = rootProject.file("key.properties")
def keystoreProperties = new Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
`;

const RELEASE = `
        release {
            if (keystorePropertiesFile.exists()) {
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
            }
        }`;

module.exports = function assinaturaRelease(config) {
  return withAppBuildGradle(config, (cfg) => {
    let gradle = cfg.modResults.contents;
    if (gradle.includes('keystorePropertiesFile')) return cfg;

    gradle = gradle.replace(/^android \{/m, `${CABECALHO}\nandroid {`);
    // Bloco release dentro de signingConfigs, logo depois do debug.
    gradle = gradle.replace(
      /(signingConfigs \{\s*debug \{[^}]*\})/,
      `$1${RELEASE}`,
    );
    // No buildType release, usa a chave release quando ela existir.
    gradle = gradle.replace(
      /(release \{\s*\/\/ Caution![^\n]*\n[^\n]*\n\s*)signingConfig signingConfigs\.debug/,
      '$1signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug',
    );
    cfg.modResults.contents = gradle;
    return cfg;
  });
};
