# O plugin de leitura de texto (ML Kit) cita os modelos de outros alfabetos
# (chinês, japonês, coreano, devanágari), mas o app usa só o latino — então
# essas classes não existem no APK e o R8 não deve reclamar delas.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
