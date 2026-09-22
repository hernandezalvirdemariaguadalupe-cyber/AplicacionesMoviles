# 1. Evolución de los modelos

## De modelo de lenguaje (LM) a modelo de lenguaje grande (LLM)

Un **modelo de lenguaje** (*Language Model*, LM) es un sistema estadístico entrenado para
estimar la probabilidad de una secuencia de palabras (o *tokens*), es decir, para predecir
qué token es más probable que siga a los anteriores. Antes de 2017, esto se resolvía con
modelos relativamente pequeños (n-gramas, redes recurrentes tipo LSTM) entrenados para
tareas específicas y con capacidad limitada para capturar dependencias de largo alcance en
el texto.

El punto de inflexión fue la arquitectura **Transformer** (Vaswani et al., 2017), que
reemplazó la recurrencia por un mecanismo de *atención* capaz de relacionar cualquier par
de posiciones en una secuencia sin importar la distancia entre ellas, y que además se
puede paralelizar de forma masiva en GPU/TPU. Esto permitió escalar tres variables a la
vez: el número de parámetros del modelo, el volumen de datos de entrenamiento y el cómputo
disponible. Cuando estas tres variables crecieron varios órdenes de magnitud (de millones
a cientos de miles de millones de parámetros), aparecieron capacidades que los modelos
pequeños no mostraban de forma explícita —traducción, resumen, respuesta a preguntas,
programación— sin haber sido entrenados específicamente para cada una. A esta nueva
generación, entrenada sobre corpus masivos de texto con arquitecturas Transformer de gran
escala, se le llama **modelo de lenguaje grande** (*Large Language Model*, LLM): GPT,
Claude, Gemini, Llama, entre otros.

En resumen, un LLM no es una tecnología distinta de un LM: es la misma tarea
(predecir el siguiente token) llevada a una escala de parámetros, datos y cómputo lo
suficientemente grande como para que emerjan capacidades generales de lenguaje que no
estaban presentes en los modelos más pequeños.

## Modelos con razonamiento explícito

A partir de 2024-2025 surgió una nueva categoría: los **modelos con razonamiento
explícito** (*reasoning models*), como la serie o1/o3 de OpenAI o los modos de
"pensamiento extendido" de Claude y Gemini. Estos modelos, antes de dar una respuesta
final, generan una secuencia intermedia de pasos de razonamiento (una especie de
"borrador" interno) que les permite planear, verificar y corregirse antes de producir la
respuesta visible al usuario.

Es importante ser precisos en un punto que suele confundirse: **esta capacidad no aparece
solo por hacer el modelo más grande**. Dos factores específicos la producen:

1. **Técnicas de entrenamiento adicionales**: después del preentrenamiento habitual, estos
   modelos pasan por una etapa de aprendizaje por refuerzo (RL) en la que se les recompensa
   específicamente por producir cadenas de razonamiento que lleven a respuestas correctas
   y verificables (matemáticas, código, lógica), no solo por imitar texto humano. Esto es
   una fase de entrenamiento distinta y adicional, no una consecuencia automática del
   tamaño del modelo.
2. **Cómputo adicional en el momento de la inferencia** (*test-time compute* /
   *inference-time compute*): en lugar de generar la respuesta en un solo paso, el modelo
   "gasta" más tiempo de cómputo por cada pregunta generando y evaluando pasos de
   razonamiento antes de responder. Esto significa que, para una misma arquitectura y
   tamaño de modelo, se puede mejorar la calidad del razonamiento simplemente asignándole
   más cómputo por respuesta (más tokens de razonamiento), un eje de escalamiento distinto
   al de "más parámetros" o "más datos de entrenamiento".

En otras palabras: el razonamiento explícito es el resultado de decisiones deliberadas de
entrenamiento (RL orientado a razonamiento verificable) y de arquitectura de inferencia
(permitir y presupuestar más cómputo por respuesta), no un efecto secundario que aparezca
solo por aumentar el número de parámetros del modelo.

## Referencias de este documento

- Vaswani, A., Shazeer, N., Parmar, N., Uszkoreit, J., Jones, L., Gomez, A. N., Kaiser, Ł.,
  & Polosukhin, I. (2017). *Attention is all you need*. Advances in Neural Information
  Processing Systems, 30. https://arxiv.org/abs/1706.03762
