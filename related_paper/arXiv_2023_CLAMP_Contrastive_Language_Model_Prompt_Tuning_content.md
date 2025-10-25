                                                            CLAMP: Contrastive LAnguage Model Prompt-tuning

                                                Piotr Teterwak1       Ximeng Sun1 Bryan A. Plummer1 Kate Saenko1                                        Ser-Nam Lim2
                                                                      Boston University1 Unversity of Central Florida2
                                                                    {piotrt,sunxm,bplum,saenko}@bu.edu                   sernam@ucf.edu
arXiv:2312.01629v1 [cs.CV] 4 Dec 2023




                                                                Abstract

                                            Large language models (LLMs) have emerged as pow-
                                        erful general-purpose interfaces for many machine learn-
                                        ing problems. Recent work has adapted LLMs to genera-
                                        tive visual tasks like image captioning, visual question an-
                                        swering, and visual chat, using a relatively small amount of
                                        instruction-tuning data. In this paper, we explore whether
                                        modern LLMs can also be adapted to classifying an im-
                                        age into a set of categories. First, we evaluate multimodal                   What is unusual about this image?

                                        LLMs that are tuned for generative tasks on zero-shot im-
                                                                                                                      The unusual aspect of this image is the presence of a
                                        age classification and find that their performance is far be-                 small car parked in front of a large airplane. Typically,
                                        low that of specialized models like CLIP. We then propose                     cars are not parked near airplanes, …
                                        an approach for light fine-tuning of LLMs using the same
                                        contrastive image-caption matching objective as CLIP. Our                     Is this a hatchback?
                                        results show that LLMs can, indeed, achieve good image
                                        classification performance when adapted this way. Our ap-                     Yes, the car in the image is a hatchback.
                                        proach beats state-of-the-art mLLMs by 13% and slightly
                                        outperforms contrastive learning with a custom text model,
                                                                                                            Figure 1. State-of-the-art multimodal LLMs excel at generative
                                        while also retaining the LLM’s generative abilities. LLM            visual tasks like answering questions that involve common sense,
                                        initialization appears to particularly help classification in       but underperform on standard image classification tasks like pre-
                                        domains under-represented in the visual pre-training data.          dicting the car type (generated using LLaVA1.5 [29]). On a suite
                                                                                                            of 24 zero-shot image classification datasets they underperform
                                                                                                            SOTA zero-shot classification models like CLIP [38] by 13%. In
                                        1. Introduction                                                     this paper, we present an approach to improve classification while
                                                                                                            retaining the LLM’s generative abilities.
                                        In the past several years the capabilities of Large Language
                                        Models (LLMs) have progressed from interesting to ex-
                                        tremely useful. This success is equal parts data and com-           be useful. In this paper we ask, can multimodal LLMs
                                        pute; LLaMA2 [48] is trained on 2 trillion tokens and mil-          also perform zero-shot classification tasks? For instance,
                                        lions of GPU-hours. Recent work has adapted LLMs to                 given a list of vehicle types and an image, can an mLLM
                                        multimodal inputs such as images, by learning a mapping             identify which type of vehicle is present (Fig. 1)? We find
                                        from a frozen visual backbone to a continuous token used            that the answer is, surprisingly, not well. For example, state-
                                        as input to the LLM. Such multimodal LLMs (mLLMs) in-               of-the-art mLLMs get under 10% top-1 classification accu-
                                        clude LLaVA [29], MiniGPT [59], Instruct-BLIP [9], and              racy on Stanford Cars [22], while CLIP achieves over 80%
                                        GPT-4V [35] and have impressive image captioning and                (Tab. 1). This is counter-intuitive; LLMs have been proven
                                        question-answering capabilities. For example, several of            to encode extensive knowledge about the world. In fact, one
                                        these models can effectively answer why a picture of some-          can even ask an LLM what an object looks like, and get a
                                        one ironing clothing on the back of a moving taxi-cab is            reasonable answer.
                                        unusual (see GPT-4 Technical Report[35], Table 16.)                    We hypothesize that this weakness is due not to a lack of
                                           Yet generative tasks like visual-question answering are          capability of the LLM but to improper training, and that the
                                        not the only place where LLM world-knowledge could                  generative captioning and instruction-tuning objectives do


                                                                                                        1
                       minivan sports car SUV
                                                                                rate nor efficient at zero-shot image classification.
              GPTScore 0.13      0.05 … 0.03 …
                                                                              • We create a new form of multimodal LLM which replaces
                                                                                the text encoder of a contrastive vision-language model
                                    LLM
                                                                                with a pretrained LLM and updates a limited set of pa-
                                                                                rameters using a contrastive loss.
                          ImageA          I1        photo of      a           • We show that the LLM initialization allows for improved
                          Encoder
                                                    Prompt                      performance in domains under-represented in the pre-
                                                                                training data, and that our CLAMP retains generative
       a) Applying a Multimodal LLM for Zero-Shot Classification
                                                                                abilities despite our fine-tuning.
       1 minivan
       2 sports car             LLM                                           2. Related Work
            …




       n   SUV                                                                Contrastive Training. Contrastive training has become a
       Class Names
                                                       T1    T2   …           popular training technique. It aims to align positive pairs
                              Image                                           in embedding space, while pushing negative pairs apart.
                              Encoder
                                               I1      0     1 … Tn
                                                                              Therefore, this type of method strongly depends on how
                                                                      0
                                                                              positive and negative pairs are formed. Some methods con-
             b) CLAMP for zero-shot classification (ours)
                                                                              trast images with their augmented selves [3, 21, 34, 47],
Figure 2. Adapting LLMs for image classification: a) Applying                 while Vision-Language models (e.g. CLIP [38]) use a text-
prior multimodal LLMs such as LLaVA [29] and MiniGPT [59] to                  encoder and contrast against text captions [38, 55, 56],
classification by computing the GPTScore [27] has poor accuracy;              therefore learning a joint image-text embedding. This joint
b) Our approach CLAMP achieves high accuracy by lightly fine-                 embedding space enables Vision-Language models to clas-
tuning the LLM with a contrastive image-caption objective.                    sification in the zero-shot setting, without training data with
                                                                              explicit labels. In this work, we add a contrastive objec-
                                                                              tive to fine-tune an LLM, and therefore enable the LLM to
not enable effective classification. To build some intuition                  function as an effective zero-shot visual classifier.
for this, consider that LLMs contain a powerful language                      Large Language Models. Large Language Models are
prior which may improve visual-question answering even                        transformers [49], scaled to billions of parameters, trained
without image features; for example, the correct answer                       generatively on trillions of tokens. LLMs are commonly
may simply have higher-likelihood in the language model,                      trained with next-token prediction. The success of LLM-
as illustrated by Visual GPT-Score [27]. In that work, it was                 based chatbots such as ChatGPT has inspired a great num-
shown that SoTA performance can be achieved on several                        ber of efforts to create both general [6, 35, 48, 58] and
vision-language benchmarks by ignoring the context image                      domain specific [41, 50] language models. Instruction-
completely and just computing the likelihood of the text se-                  tuning additionally fine-tunes LLMs with (instruction, out-
quences using the language model.                                             put) pairs, which makes LLMs more useful for specific
    Given our hypothesis that generative training is not suf-                 tasks. In this work, we explore adapting an LLM to image
ficient for discriminative image tasks, but that LLMs still                   classification.
encode knowledge useful for those tasks, we propose to                        Regularized Fine-tuning. Also known as Parameter-
use an LLM as a text encoder together with contrastive                        Efficient Fine Tuning (PEFT), regularized fine-tuning aims
language-image pre-training (e.g. CLIP [38]). We call                         to update only a subset of the parameters in a pre-trained
our method Contrastive LAnguage Model Prompt-tuning                           model. This allows one to keep around only a small number
(CLAMP) (Fig. 2.) We find that by updating a minority of                      of parameters for each specialized task a model is fine-tuned
the LLM parameters, our method can approach the perfor-                       for, to use less memory in the training process, and to not
mance of zero-shot CLIP trained on much larger scale data                     unlearn knowledge present in the pre-trained model. Com-
while outperforming a text-encoder trained from scratch on                    mon approaches include low-rank updates of existing ma-
the same data. This finding highlights the benefits of using                  trices (LoRA [17]), prompt and prefix tuning [25, 26, 30],
Large Language Models; LiT [55] finds that initializing to                    and inserting additional trainable layers into the middle of
pre-trained (but smaller scale) LMs is not helpful for zero-                  the network (Adapters [16]). In our work, we use prompt
shot classification in English. Surprisingly, we’re also able                 tuning and LoRA to adapt the LLM to the contrastive text-
to mostly retain the generative capabilities of the language                  image task.
model, pointing towards universal generative and discrimi-                    Multimodal Large Language Models. Until recently,
native models.                                                                large LMs have operated exclusively in the text domain.
    In summary, our contributions as the follows:                             However, a plethora of models such as LLaVA [29], GPT-
• We show that SOTA multimodal LLMs are neither accu-                         4V [35], MiniGPT [59], Flamingo [1], and BLIP [9] now


                                                                          2
can take images as input. These models typically use a pre-           (Section 3.1.3) in the intermediate layers. Similar to many
trained vision encoder and a small set of learnable parame-           mLLMs, we freeze the visual encoder.
ters to map from vision encoder output to LLM input. They
are typically trained with a captioning loss, and can addi-
                                                                      3.1.1     Read-only Prompts
tionally be tuned with an instruction-tuning objective. The
base LLM can be frozen [59] or updated [48]. Multimodal               Frozen LLMs are generative models, therefore in order
LLMs work well for tasks such as visual question answer-              to add discriminative capabilities we need to modify the
ing or captioning. However, we show that they are generally           model. However, doing so without without harming the
ineffective for zero-shot classification.                             good representations learned during pre-training requires
                                                                      care, and one method used to do so is prompt tuning. We
3. Contrastive LAnguage Model Prompting                               do so by appending learnable prompts to the end of the text
                                                                      sequence, which function as special-purpose tokens for dis-
We propose Contrastive LAnguage Model Prompt-tuning                   criminative tasks.
(CLAMP), a method to adapt Large Language Models to
classification via prompting and contrastive learning. Our                                  x = [xtext ; {plearnable }]                (1)
approach is inspired by state-of-the-art vision-language
models trained with the contrastive objective, i.e. CLIP. The         where x is the input sequence to the LLM, xtext is the to-
objective encourages a strong alignment between text and              kenized language and plearnable are the learnable prompts.
image representations in a joint space, enabling effective-           The LLM we use uses causal attention, meaning each po-
zero shot classification. We propose to align LLM represen-           sition’s representation can only attend to tokens previously
tations with visual representations using a contrastive loss.         seen in the sequence. When attention is bi-directional, the
The question is, how to prompt the LLM to output a rep-               intermediate representations of xtext can shift with changes
resentation that is useful for image classification? After all,       in plearnable . With causal attention, however, plearnable can
the information needed to predict the next token in a caption         change without updating intermediate representations of
(language modeling) is not necessarily the same as that to            xtext . Such a technique is known as read-only prompting
encode the visual category in that same caption.                      [25], and it is shown to improve generalization of prompt-
    CLAMP accomplishes this in three main ways. First, it             tuning of contrastive vision-language models to unseen
learns a pooling over the LLM’s output representations. We            classes, due to minimizing overfitting. To produce the text
implement this with attention-pooling (Section 3.1.2), with           embedding, we perform output attention pooling over the
a query token that learns to aggregate the output represen-           output representations of the learnable prompt tokens.
tations of an encoded caption. However, output pooling is
insufficient to get the LLM to produce useful information             3.1.2     Output Attention Pooling
that is embedded in the remaining network layers. To over-
come this, CLAMP adds learned read-only prompts [25]                  Transformer networks take as input variable-length se-
(Section 3.1.1), which serve as special-purpose discrimina-           quences, and output sequences of that same length. How-
tive tokens in a model pre-trained for generation. Finally,           ever, the joint image-text embedding space of vision-
we find that slight modification of the parameters improves           language models requires a representation of a fixed length.
zero-shot performance further, accomplished with LoRA,                Therefore, some kind of pooling of tokens is needed. CLIP
which learns low-rank delta updates of certain layers (Sec-           [38] accomplishes this by simply using the last token in the
tion 3.1.3.)                                                          sequence as as the representation of the text. We instead
    Section 3.2 details the text prompt used in training and          use the read-only prompts described in the previous section.
Section 3.3 describes the training objective, which includes          However, since we use many of those prompts, we still need
distillation of a stronger CLIP model into our trained model,         to pool them to a fixed length. We choose to leverage a form
inspired by Dime-FM [44].                                             of pooling that uses the multi-headed attention mechanism:

3.1. Architecture
                                                                            Attention(Q, K, V ) = Concat(head1 , . . . , headh )WO     (2)
In our experiments, we build on top of Vicuna-1.5 [5],
which is a LLaMA-2 based instruction-tuned model. We                  where
align the Vicuna with a pre-trained visual encoder con-
                                                                                  headi = Attention(QWQi , KWKi , V WV i )             (3)
trastively. In order to do so without risking overfitting,
we only add a small number of trainable modules includ-               and
ing Output Attention Pooling (Section 3.1.2) at the output,                                                         
                                                                                                                        QK T
                                                                                                                               
Read-Only Prompts (Section 3.1.1) at the input, and LoRA                         Attention(Q, K, V ) = Softmax          √          V   (4)
                                                                                                                          dk

                                                                  3
   In our attention pooling mechanism, we learn the query           3.3. Contrastive Training of LLMs
Q and the K and V are simply output tokens of the LLM. In
                                                                    So far, we have discussed the architectural components of
this way, we can learn a per-sample linear combination of
                                                                    our method. We now turn our attention to the training
LLM outputs.
                                                                    methodology. Following CLIP [38], we use image-text and
                                                                    text-image contrastive losses:
3.1.3   LoRA
                                                                                               X          exp(τ viT ti )
While Attention Pooling and Read-Only Pooling are impor-                       Limg2txt = −          log P          T
                                                                                                                                  (6)
                                                                                                 i        j exp(τ vi tj )
tant architectural components in extracting discriminative
features from text sequences, discriminative performance                                       X          exp(τ tTi vi )
can further be improved if the network parameters can be                       Ltxt2img = −          log P          T
                                                                                                                                  (7)
                                                                                                 i        j exp(τ ti vj )
lightly updated. One option is full-finetuning of the net-
work parameters. This, however, has two large drawbacks.
                                                                                Lcontrastive = Limg2txt + Ltxt2img                (8)
First, it has heavy memory requirements. In particular, for
the large-batch training necessary for effective contrastive        where t is a text representation, v is a visual representation,
learning, full fine-tuning requires the storage of intermedi-       and i and j index the batch. τ is a learned temperature pa-
ate activation. Secondly, we go back to the motivation of not       rameter.
catastrophically forgetting information present in the LLM              In addition, we add a distillation loss term to the training,
in our contrastive training. Therefore, we leverage LoRA,           similar to Dime-FM [44]. Following [44], we first compute
which learns low rank updates to pretrained models:                 teacher similarity matrix St and student similarity matrix
                                                                    Ss . These are computed using the vision and text encoders
                     W = W0 + BAT                         (5)       over samples in the batch, as in the contrastive loss. Defin-
                                                                    ing row-wise indexing variable as i and column-wise index-
where W are the updated weights in Rd×d , and B and A               ing variable as j, the distillation loss is defined as:
are in Rd×k :
   As is common, we only update multi-headed attention                         X                          X
layers with our LoRA updates. We use a rank of 16, an α of           Ldist =        KL(τd St ||τd Ss )+       KL(τd StT ||τd SjT ) (9)
16, a droput value of 0.1, and no bias terms.                                   i                         j


3.2. Wrapper prompts                                                Finally, our loss becomes:

Vicuna is trained with a very specific prompt template:                              Ltot = Lcontrastive + Ldist                 (10)
“A chat between a curious user and an artificial intelligence
assistant. The assistant gives helpful, detailed, and polite        4. Experiments
answers to the user’s questions.                                    We evaluate our models on zero-shot classification tasks
USER: Hello!                                                        in order to test the discriminative ability of our adapted
ASSISTANT: Hello!”.                                                 large language models. We compare to two sets of mod-
    In order to follow this format of USER followed by AS-          els; a.) To existing multimodal Large Language Models
SISTANT, we use the following prompt template for our               LLaVA [29] and Mini-GPT [59], to demonstrate how naive
training:                                                           usage of existing mLLMs does not meet the expectations
                                                                    of modern zero-shot classifiers, and b.) To a contrastive
“USER: A photo of a {}. A {} has the following visual at-           vision-language model where we retrain the parameters of
tributes.                                                           the text encoder, also known as LiT [55]. We select a di-
ASSISTANT: 1.”                                                      verse set of 24 datasets to evaluate zero-shot performance,
Where the {} is replaced with the caption of a particular           including fine-grained datasets such as Stanford Cars [22]
sample. Auto-regressive decoding of this prompt would re-           and Aircraft [31], natural but challenging datasets such as
sult in a description of what the image with the caption may        EuroSAT[14] and ImageNet[10], and synthetic data such as
look like. Although auto-regressive decoding in the training        Kitti [13].
loop is prohibitively expensive; Xiao et al. [51] show that            Since we aim for our models to retain their generative
much information about the decoded sequence is present              abilities in addition to gaining discriminative abilities, we
in the initial tokens, and therefore prompting the LLM to           show how our models can continue to generate effectively
describe the caption is a reasonable way to surface visual          with both qualitative examples and quantitative metrics, eg.
information.                                                        on MMLU[15]. This shows the universality of our model.


                                                                4
                                                                                                       ance




                                                                                                                                                     yon
                                              ft




                                                                 T2




                                                                                                       nt
                                        ircra




                                                                                                    et.
                                                                                                  Dist

                                                                                                  Cou
                   t 1k




                                                               dSS




                                                                                                                                                  mel
                                       211




                                                                                                100
                                                                                                  01




                                                                                                  R
                                                                                                10




                                                                                                                                 SAT
                     e




                                    CA




                                                                                            LAB




                                                                                                                                                                   5
                                                                                            ech1




                                                                                             etic
                                                              dere




                                                                                                                                              hCa




                                                                                                                                                                          rage
                                   ntry




                                                                                            VR

                                                                                             VR
                                    RB
                  geN




                                                                                                                                 ers
                                                     IST




                                                                                                                                                              isc4
                                                                                 397



                                                                                           AR

                                                                                           AR
                                                                         10




                                                                                                                                                                N
                                                                                       DTD



                                                                                                                           Flow
                                FGV




                                                                                                                                                            SVH
                                                                                       Diab




                                                                                                                           Euro
                                GTS




                                                                                       CLE

                                                                                       CL E
                         Cars




                                                                                                                               i
                                                                     STL




                                                                                                                                         Patc
                                Cou




                                                                                       Calt




                                                                                                                                         Pets
                                                   MN

                                                           Ren




                                                                                       DM




                                                                                                                                                                       Ave
              Ima




                                                                              Sun



                                                                                       CIF

                                                                                       CI F




                                                                                                                           Kitt




                                                                                                                                                           Res
LLaVa v1.5  30.7 5.6 3.6 6.7 34.6 84.9 62.8 98.2 43.3 65.1 12.5 54.8 9.1 12.5 2.3 21.3 26.1 33.4 12.5 37.7 49.2 15.1 39.1 54.2 34.0
minigpt4    24.0 8.9 4.8 6.5 31.7 58.4 52.9 93.1 36.4 63.1 30.2 60.8 9.1 12.7 2.3 12.4 21.1 31.4 30.2 31.5 50.8 26.8 26.7 45.5 32.1
LiT [55]    64.0 74.6 11.7 9.4 43.2 36.4 48.4 97.6 65.5 82.2 67.9 91.9 11.0 13.3 2.3 19.7 36.1 47.7 66.5 18.7 56.4 80.8 50.4 17.0 46.4
CLAMP(Ours) 63.0 78.7 12.7 16.3 31.8 45.7 51.5 96.4 66.4 81.1 65.3 88.4 11.2 14.9 4.4 14.9 49.3 47.8 64.9 24.2 50.2 78.3 42.6 28.3 47.0

Table 1. Comparison of CLAMP with multimodal Large Language Models and LiT. We find that a contrastive finetuning of LLMs
outperforms current SOTA multimodal LLMs such as LLaVA v1.5 [29] and minigpt4[59] by 13%. LLaVA tends to outperform on datasets
needing OCR (such as MNIST, RenderedSST, and SVHN), but this is more than made up for with major performance degradation on
find-grained datasets such as Cars and Aircraft. CLAMP replaces the text encoder with an LLM, and lightly updates it with a contrastive
loss. This is much more performant on average than current multimodal LLMs for zero-shot classification, and even outperforms or is on
par with a vision-language model trained on the same data (LiT). In Table 2, we show that CLAMP strongly outperforms LiT in regimes
where the target data is not well covered in pre-training.


4.1. Multi-modal LLMs as Zero-shot Classifiers                                                    image-text contrastive loss in addition to distilling a ViT-L-
                                                                                                  14 trained on DataComp XL [? ] into the model. Addi-
We compare our method to the multimodal Large
                                                                                                  tional training details are in the supplementary. When we
Language Models by computing the likelihood of an
                                                                                                  do zero-shot evaluation, we use a prompt template match-
image-class caption sequence, following Flamingo[1]and
                                                                                                  ing the training prompt (Section 3.2).
VisualGPTScore[27]. In more detail, given an image I
                                                                                                  Baselines:
and a set of class labels, for each class label c consisting
                                                                                                  MiniGPT4 [59]: MiniGPT4 learns a linear mapping be-
of one or more tokens, we compute the likelihood of se-
                                                                                                  tween the output of a pre-trained CLIP encoder and a frozen
quence P (‘A photo of c’|I). We additionally normalize by
                                                                                                  LLM, trained using Conceptual Captions. In our experi-
the sequence length, because longer sequences generally
                                                                                                  ments, we use a MiniGPT4 with a 16-bit Vicuna13B model.
have lower likelihood and this is not a sensible prior for
                                                                                                  LLava-1.5 [28]: LLaVa-1.5 is similar to MiniGPT in ar-
classification. Then, the score for each class is:
                                                                                                  chitecture, but with a different data mixture. In particu-
                           N                                                                      lar, LLava-1.5 combines academic VQA datasets with an
                  1 X
                        log(P (ti |t0..i−1 ; I))                                       (11)       expansion of COCO by ChatGPT [29] to create a vision-
                  N i=1                                                                           language instruction-following dataset. LLaVA-1.5 also
where N is the sequence length, I is the image to be classi-                                      finetunes the LLM with LoRA.
fied, and t are the sequence tokens. To classify, we simply                                       LiT[55]: To compare to state-of-the art contrastive vision-
select the score with the highest normalized log-likelihood.                                      language models, we train a LiT model, which keeps the
                                                                                                  vision encoder frozen while updating all text encoder pa-
4.2. Zero-shot classification                                                                     rameters. We initialize with a ViT-B-16 CLIP text encoder
                                                                                                  from scratch, and train on the same data and for the same
Training and Evaluation Setup: For the text encoder, we                                           length as our model. For LiT models, we use an evaluation
use a pre-trained Vicuna13B-1.5[5], which uses LLaMa2 as                                          prompt template of ‘A photo of {class}’. We use a single
a base model. We enable attention pooling (Section 3.1.2),                                        prompt template for evaluating both LiT and CLAMP.
Read-Only Prompting (Section 3.1.1) with 24 soft prompts,
and LoRA (Section 3.1.3) as the text encoder trainable pa-                                        Results: We present the performance of our model in Table
rameters. For the vision encoder, we use an OpenClip                                              1. We find that on average, we outperform generatively-
pretrained ViT-B-16, and keep it frozen. We train with a                                          trained LLaVA-v1.5 and miniGPT-4 by 13% and the LiT
data mixture of Conceptual Captions 3M[40], Conceptual                                            baseline by half a percent. This demonstrates that adding a
Captions 12M[2], a 200-million scale subset of LAION-                                             contrastive loss to an LLM, together with light fine-tuning,
400M[39], and ImageNet-21k[10]. All of these datasets,                                            adds a visual discriminative ability to LLMs which current
except for ImageNet21k, are image-caption datasets. In                                            SOTA captioning models do not have. We further ana-
contrast, ImageNet21k is a dataset of approximately 21000                                         lyze where we outperform LiT in Section 4.2, and find that
labels. In order to convert this to an image-caption dataset,                                     our method is particularly useful when there is little target
we wrap each label in one of the 80 prompt templates used                                         data present in the pre-training data (see count in Coverage
in the CLIP paper [38]. We train for 480 million seen ex-                                         Analysis).
amples, with a batch size of 8192. We use the standard                                            Runtime:     Applying mLLMs using likelihoods (GPT-


                                                                                              5
                                                                                                                         athy




                                                                                                                         ll
                                                                                                                    ance

                                                                                                                    nt A
                                                                                                                     nop
                                                                                                                   yon
                                                                                                                   raft




                                                                                                                    T2
                                                                                                                Reti




                                                                                                                Dist

                                                                                                                Co u
                                                                   k




                                                                                                               dSS
                                                                                                               mel
                                              211




                                                              et 1




                                                                                                              Airc
                                                             100

                                                               01
                                              10
                          SAT




                                                             5




                                                                                                          LAB
                                                         ech1




                                                                                                           etic


                                                                                                          dere
                                                                                                           hCa
                                                        rage




                                                                                                                                              e
                                          ntry




                                                                                                           VR

                                                                                                           VR
                                          RB




                                                        geN
                                                          ers
                                                        isc4




                                                                                                          IST
                                                        397
                                         AR




                                                        AR




                                                                                                                                             rag
                                 10




                                                                                                            N
                                                                                                       C
                                                                                              DTD
                                                    Flow




                                                                                                    FGV




                                                                                                      SVH
                         Euro




                                                                                                      Diab
                                      GTS




                                                                                                      CLE

                                                                                                      CLE
                     i




                                                                                       Cars
                                STL




                                                                                                      Patc
                                      Cou




                                                    Calt




                                                    Pets




                                                                                                      MN

                                                                                                      Ren




                                                                                                      DM
                                                    Ave




                                                                                                                                         Ave
                 Kitt




                                      CIF




                                                    CIF




                                                    Sun

                                                    Ima
                                                    Res
                                         High Count                                                      Low Count
Coverage    1.00 0.70 1.00 0.96 1.00 0.47 0.76 0.77 0.47 0.67 0.65 0.82 n/a 0.86 0.47 0.13 0.38 1.00 0.20 0.00 0.00 0.00 0.00 0.00 0.00 n/a
Count      2101.5k 24.5k 23.5k 22.2k 17.6k 17.3k 14.3k 7.8k 5.9k 3.9k 3.7k 2.5k n/a 503 432 219 171.9 18 1.8 0.00 0.00 0.00 0.00 0.00 0.00 n/a
LiT         18.7 47.7 97.6 11.7 91.9 43.2 67.9 82.2 50.4 66.5 65.5 64.0 59.0 80.8 74.6 36.1 9.4 56.4 2.3 36.4 48.4 11.0 13.3 19.7 17.0 33.8
CLAMP(Ours) 24.2 47.8 96.4 12.7 88.4 31.8 65.3 81.1 42.6 64.9 66.4 63.0 57.0 78.3 78.7 49.3 16.3 50.2 4.4 45.7 51.5 11.2 14.9 14.9 28.3 37.0
ZS CLIP     15.2 45.0 97.0 15.9 91.8 43.5 67.6 84.9 53.4 65.0 69.2 64.7 59.4 86.6 82.3 47.6 17.0 52.5 2.3 33.9 53.7 24.5 21.5 14.7 19.0 38.0

Table 2. Comparison based on concept count. We sort datasets based on count of target classes within our LAION-200M subset.
Coverage indicates the fraction of classes present within pre-training captions as a noun-phrase. Count counts the number of times the
class set is present in the pre-training data captions, normalized by the number of classes. We then divide the datasets in half, into high
count and low count datasets. We find that our method outperforms the LiT [55] baseline on the low count datasets by 3% on average and
up to 13% (DTD). This shows the benefit of language pre-training for low-coverage datasets. For reference, we also add zero-shot CLIP-
ViT-B 16, trained on LAION-400M (ZS CLIP). Even though the ZS CLIP model is trained on almost 1.5x the data, CLAMP approaches
its performance. For more discussion, see Section 4.2.


Score) to do zero-shot classification is extremely inefficient;         pre-training data only has about 170 samples per aircraft
for example evaluating LLaVA on the ImageNet test set                   type, and our model outperforms the LiT baseline by about
takes 12 hours 52 minutes on 10 GPUs. This is because each              7%. In other words, the knowledge imported by the very
image needs to be forwarded through the LLM N times,                    large-scale text-based pre-training of an LLM allows us
where N is the number of classes. In contrast, it takes our             to generalize better than simply training on image-caption
method minutes for the same evaluation, as we can precom-               pairs. This highlights the benefits of LLM-based discrimi-
pute the text embeddings ahead of time and we avoid the                 native zero-shot classification.
combinatorial explosion of early fusion.                                    Two datasets which appear to refute the rule are Kitti
Coverage Analysis One benefit of large scale pre-training               (with very high coverage and count, but lower performance)
is improved performance on data which is similar to the                 and PatchCamelyon (low coverage count, and also lower
pre-training data, but less similar to the fine-tuning data.            performance). PatchCamelyon is a dataset of histopatho-
To check whether this is the case with our models, we uti-              logic scans of lymph node sections annotated with a bi-
lize a metric from [53] called Concept Coverage to measure              nary label indicating presence of cancer. This is a very
the presence of evaluation data in the pre-training dataset.            difficult concept to describe in natural language; in fact hu-
The methodology uses spaCy 1 . Following [53], we iterate               mans trained to do this task must be highly specialized and
over all the captions in our LAION subset and extract noun              undergo many years of training. Therefore, a model pre-
chunks, adding them into a dictionary. Finally, we filter out           trained on language data may not be appropriate. The sec-
all noun chunks which appear fewer than 5 times. Then, we               ond dataset is Kitti. Looking more closely at the Kitti class
compute two metrics for each downstream dataset. First,                 labels, we have the set {‘a photo of a photo i took of a car
we check how many class labels are present in the concept               on my left or right side’,‘a photo i took with a car nearby’,‘a
dictionary, and report this as fraction of all labels which we          photo i took with a car in the distance.’,‘a photo i took with
call coverage. Second, we compute the average number of                 no car.}. These labels have nouns which are not discrimina-
pre-training images per class label in the target set, and call         tive, ‘car’ and ‘photo’, so the concept coverage heuristic is
this count. We present the results in Table 2.                          not fully relevant for this dataset. Instead the descriminative
    We can observe two things. First, there is a strong cor-            labels are adjectives corresponding to distance.
relation between absolute performance and concept counts.
                                                                        4.3. Generative Abilities of Finetuned models.
When we split the evaluation datasets into “high count” and
“low count”, “high count” has much higher average perfor-               As one of our aims is to take steps towards model univer-
mance. Second, in the “low count” regime , our model out-               sality, an important metric is whether we retain generative
performs the LiT baseline on average. For example, Cars                 capabilities in our models even after our discriminative fine-
only has about 432 samples per vehicle type, and our model              tuning. One could expect that contrastive adaptation would
outperforms the LiT baseline by over 4%. Similarly, our                 ruin the generative abilities of the model.

   1 https://spacy.io/




                                                                    6
Category               Prompt and Output
                       Prompt: Write a short story about a dragon who was evil and then saw the error in [sic] it’s ways.
                       Output: Once upon a time, in a land far, far away, there lived a dragon named Draco. Draco
                       was known throughout the land as the most evil dragon that had ever lived. He would terrorize
Creative writing       the countryside, burning down villages and towns, and eating anyone who crossed his path. The
                       villagers lived in fear of Draco, and many had lost loved ones to his fiery breath. Howeverever, one
                       day, Draco came across a group of villagers who were lost in the woods. They were terrified of him,
                       but he saw that they were not armed and did not seem to be dangerous. He decided to let them go,
                       and as they walked away, he heard a voice in his head telling him that he was wrong to terrorize the
                       countryside. He realized that he had been evil all his life, and that he had no reason to be so cruel to
                       others. From that day on, Draco changed his ways and became a kind and gentle dragon. He helped
                       the villagers and protected them from other dangerous creatures in the woods. The villagers were
                       amazed and grateful to Draco, and they all lived happily ever after. The end.
                       Prompt: How was Anne Frank’s diary discovered?
                       Output: Anne Frank’s diary was discovered by chance. In 1944, the Nazis occupied the Netherlands
                       and the Frank family went into hiding in an attic above the office of the company where Anne’s father
Factual Questions
                       worked. The attic was used as a storage room and was not used for several months. The employees
                       of the company were moving out of the building and found the hidden attic and the hidden door to
                       the attic. They found the diary and other documents hidden behind a false wall in the attic. They
                       took the diary and other documents to the office manager, who recognized Anne Frank’s name and
                       realized the significance of what he had found. He kept the diary and other documents safe until
                       after the war, when he returned to the office and found the diary among his papers. He then gave
                       it to the Anne Frank Foundation, which published the diary and helped bring Anne Frank’s story to
                       the world.
                       Prompt: I sit in front of a computer all day. How do I manage and mitigate eye strain?
                       Output: To manage and mitigate eye strain, follow these steps: 1. Take regular breaks: Every 25
                       minutes, take a 15-20 second break, look away from the screen, and focus on something 20 feet
Personal & profes-
                       away. 3. Adjust your monitor: Position your monitor at a comfortable distance from your eyes,
sional development
                       and adjust the brightness and contrast to reduce glare. 4. Use proper lighting: Ensure adequate
                       lighting in your workspace to reduce glare and reflections. 5. Blink frequently: Blinking helps to
                       keep your eyes moist and reduces the strain. 6. Consider computer glasses: If you already wear
                       prescription glasses, consider computer glasses with a higher add power for reading and computer
                       work. 7. Practice the 20-20-20 rule: Every 20 minutes, look at something 20 feet away for 20
                       seconds. 8. Consider blue light filter glasses: Blue light filter glasses can help reduce digital eye
                       strain. 9. Maintain good posture: Sit up straight, with your feet flat on the floor, and your shoulders
                       relaxed. 10. Exercise regularly and maintain a healthy diet: A healthy lifestyle can help reduce eye
                       strain and other health issues.
Casual advice & rec-   Prompt: I keep losing my keys. How can I keep track of them?
ommendations           Output: keys, you can try using a key finder or a key tracker. These devices attach to your keys
                       and allow you to locate them using your smartphone or other devices. Some popular options include
                       Tile, Chip, and KeySmart.
                       Prompt: User: A jar contains 60 jelly beans, If 35% of the jelly beans are removed how many are
                       left in the jar?
Reasoning     (math/   Assistant: If 35% of the jelly beans are removed, then the number of jelly beans left in the jar is
problem-solving)       60 − (35% of 60) = 60 − 21 = 39.
                       User: can you expand your answer to show your reasoning?
                       Output: Sure! To find the number of jelly beans left in the jar after 35% of them have been removed,
                       we need to first calculate what 35% of 60 is. We can do this by multiplying 60 by 35% (which we
                       can express as a fraction): 60 × 35% = 60 × 35/100 = 21. Then, we subtract 60 from 21 to find the
                       number of jelly beans left: 60 − 21 = 39. So there would be 39 jelly beans left in the jar after 35%
                       of them have been removed.

                          Table 3. Qualitative Examples of our finetuned LLM on NLP Generation


                                                            7
                                                                                                                       k
    We show qualitative examples in Table 3. From inspec-




                                                                                                                   et 1



                                                                                                                                 100
tion, the results are quite reasonable. We also measure




                                                                                                                                           SAT




                                                                                                                                                       rage
                                                                                                                geN




                                                                                                                                            ers
                                                                                                                              AR




                                                                                                                                            N
performance on MMLU[15]( an LLM test of 57 tasks in-




                                                                                                                           DTD



                                                                                                                                       Flow

                                                                                                                                       SV H
                                                                                                                                       Euro
                                                                                                            Cars




                                                                                                                                                    Ave
                                                                                                            Ima



                                                                                                                           CIF
cluding elementary mathematics, US history, computer sci-
ence, law, and more. To attain high accuracy on this test,
                                                                                            LoRA      63.0 78.7 65.3 49.3 47.8 64.9 28.3 56.8
models must possess extensive world knowledge and prob-
                                                                                            LN-Prefix 61.1 74.8 68.1 52.7 42.8 59.4 31.6 55.8
lem solving ability), DROP[11](a math question answering
benchmark), and BBH[45](which includes 23 eceptionally                                   Table 4. LN-Prefix Comparison. We compare with an alterna-
hard tasks). Quantitatively, Vicuna performance on MMLU                                  tive to LoRA, which is prefix tuning combined with LayerNorm
drops from 55.74 before fine-tuning to 34.91, which is bet-                              parameter tuning. We find that LoRA outperforms the LN-Prefix
ter than even much larger LLMs from a previous generation.                               combination.
For example, OPT-66B [57] achieves an MMLU of 26.99.
On DROP the degradation is lesser, from 27.73 to 24.93. On                                                  Distllation ImageNet21k LoRA ImageNet 1k Average
BBH the metric falls from 38.42 to to 32.11. We emphasize                                        All            ✓            ✓       ✓      60.4      47.2
that if the user wants to maximize generative performance,                                    - LoRA            ✓            ✓              57.9      47.0
                                                                                           - Distillation                    ✓       ✓      57.7      45.7
they can disable the LoRA parameters during inference.                                    -ImageNet21k          ✓                    ✓      60.4      46.5

4.4. Model Analysis                                                                      Table 5. Ablation Study. We observe the difference in perfor-
                                                                                         mance when we remove distillation, ImageNet-21k, and LoRA.
Effect of Data Scale: Data scale is an extremely important                               We compute both average performance across 24 datasets, and Im-
part of vision-language pretraining in general. We confirm                               ageNet1k performance. Each component is imortant.
that data scale remains very important even with our strong
language prior by subampling our data and training. In Fig-
ure 3, we show top-1 ImageNet performance as we scale                                    ing LoRA parameters, and therefore if effective would be
data. As data grows, so does top-1 accuracy.                                             well-suited for our purposes. However, as we show in Ta-
Regularized Fine-tuning Alternatives: One of our aims is                                 ble 4, in our settting LoRA is a stronger adaptation method
to retain the generative ability of the large language model;                            than prompt tuning combined with LayerNorm tuning. In
and as a result we regularize our fine-tuning so that our                                our experiments, for the Prompt + LayerNorm tuning ex-
model does not catastrophically forget that capability. We                               periments, we add 12 soft prompt tokens to the beginning
choose to combine Read-Only Prompts (Section 3.1.1) and                                  of the model, and un-freeze all LayerNorm parameters.
LoRA (Section 3.1.3). However, this is not the only choice.                              Ablations: In Table 5, we ablate several components of
In fact, Qi et al. [37] show that combining LayerNorm tun-                               CLAMP; Distillation, LoRA, and ImageNet21k. We find
ing with prompt tuning is amongst the most effective tuning                              that each piece is important for the average performance
methods. LayerNorm tuning is even lighter weight than tun-                               across all 24 evaluation datasets. Interestingly, we find that
                                                                                         adding ImageNet-21k does not improve ImageNet-1k per-
                                                                                         formance, likely because there is no overlap in class labels.
                                                  Data Scaling
                                                                                         5. Conclusion
                              57
                                                                                         In this work, we explore how to make multi-modal LLMs
    ImageNet Top-1 Accuracy




                              56                                                         work more effectively for zero-shot classification. We start
                                                                                         by showing that SOTA models such as LLaVA or miniGPT-
                              55                                                         4 do not perform well for zero-shot classification, and un-
                              54
                                                                                         derperform models trained with a contrastive captioning
                                                                                         loss by over 10%. We then show that we can add dis-
                              53                                                         criminative abilities to pre-trained Large Language Mod-
                                                                                         els by aligning an LLM with a pre-trained vision encoder
                              52
                                                                                         with a contrastive loss, and only performing a lightweight
                                   25   50   75     100    125     150   175   200       finetuning. We show that our contrastively trained LLM is
                                             Millions of Samples
                                                                                         effective at zero-shot classification, and outperforms con-
Figure 3. Scaling training data. We confirm that data scale re-                          trastively trained baselines in the regime where pre-training
mains very important even with our strong language prior by sub-                         data does not overlap with the evaluation dataset. Finally,
ampling our data and training. As data grows, so does top-1 zero-                        we show that, despite fine-tuning, our model retains gener-
shot ImageNet accuracy.                                                                  ative capabilities.


                                                                                     8
References                                                                    suite. In Conference on Computer Vision and Pattern Recog-
                                                                              nition (CVPR), 2012. 4, 13
 [1] Jean-Baptiste Alayrac, Jeff Donahue, Pauline Luc, Antoine           [14] Patrick Helber, Benjamin Bischke, Andreas Dengel, and
     Miech, Iain Barr, Yana Hasson, Karel Lenc, Arthur Mensch,                Damian Borth. Eurosat: A novel dataset and deep learning
     Katherine Millican, Malcolm Reynolds, et al. Flamingo: a                 benchmark for land use and land cover classification, 2017.
     visual language model for few-shot learning. Advances in                 4, 12
     Neural Information Processing Systems, 35:23716–23736,
                                                                         [15] Dan Hendrycks, Collin Burns, Steven Basart, Andy Zou,
     2022. 2, 5
                                                                              Mantas Mazeika, Dawn Song, and Jacob Steinhardt. Mea-
 [2] Soravit Changpinyo, Piyush Sharma, Nan Ding, and Radu                    suring massive multitask language understanding. arXiv
     Soricut. Conceptual 12M: Pushing web-scale image-text                    preprint arXiv:2009.03300, 2020. 4, 8
     pre-training to recognize long-tail visual concepts. In CVPR,       [16] Neil Houlsby, Andrei Giurgiu, Stanislaw Jastrzebski, Bruna
     2021. 5, 12                                                              Morrone, Quentin De Laroussilhe, Andrea Gesmundo, Mona
 [3] Ting Chen, Simon Kornblith, Mohammad Norouzi, and Ge-                    Attariyan, and Sylvain Gelly. Parameter-efficient transfer
     offrey Hinton. A simple framework for contrastive learning               learning for nlp. In International Conference on Machine
     of visual representations. In International conference on ma-            Learning, pages 2790–2799. PMLR, 2019. 2
     chine learning, pages 1597–1607. PMLR, 2020. 2                      [17] Edward J Hu, Yelong Shen, Phillip Wallis, Zeyuan Allen-
 [4] Gong Cheng, Junwei Han, and Xiaoqiang Lu. Remote sens-                   Zhu, Yuanzhi Li, Shean Wang, Lu Wang, and Weizhu Chen.
     ing image scene classification: Benchmark and state of the               Lora: Low-rank adaptation of large language models. arXiv
     art. Proceedings of the IEEE, 105(10):1865–1883, 2017. 13                preprint arXiv:2106.09685, 2021. 2
 [5] Wei-Lin Chiang, Zhuohan Li, Zi Lin, Ying Sheng, Zhang-              [18] Gabriel Ilharco, Mitchell Wortsman, Ross Wightman, Cade
     hao Wu, Hao Zhang, Lianmin Zheng, Siyuan Zhuang, Yong-                   Gordon, Nicholas Carlini, Rohan Taori, Achal Dave,
     hao Zhuang, Joseph E. Gonzalez, Ion Stoica, and Eric P.                  Vaishaal Shankar, Hongseok Namkoong, John Miller, Han-
     Xing. Vicuna: An open-source chatbot impressing gpt-4                    naneh Hajishirzi, Ali Farhadi, and Ludwig Schmidt. Open-
     with 90%* chatgpt quality, 2023. 3, 5                                    clip, 2021. If you use this software, please cite it as below.
 [6] Hyung Won Chung, Le Hou, Shayne Longpre, Barret                          13
     Zoph, Yi Tay, William Fedus, Yunxuan Li, Xuezhi Wang,               [19] Justin Johnson, Bharath Hariharan, Laurens van der Maaten,
     Mostafa Dehghani, Siddhartha Brahma, et al. Scaling                      Li Fei-Fei, C Lawrence Zitnick, and Ross Girshick. CLEVR:
     instruction-finetuned language models.         arXiv preprint            A diagnostic dataset for compositional language and elemen-
     arXiv:2210.11416, 2022. 2                                                tary visual reasoning. In Proceedings of the IEEE Confer-
 [7] M. Cimpoi, S. Maji, I. Kokkinos, S. Mohamed, and A.                      ence on Computer Vision and Pattern Recognition, 2017. 12
     Vedaldi. Describing textures in the wild. In Proceedings of         [20] Kaggle and EyePacs. Kaggle diabetic retinopathy detection,
     the IEEE Conf. on Computer Vision and Pattern Recognition                2015. 12
     (CVPR), 2014. 12                                                    [21] Prannay Khosla, Piotr Teterwak, Chen Wang, Aaron Sarna,
 [8] Adam Coates, Andrew Ng, and Honglak Lee. An Analysis                     Yonglong Tian, Phillip Isola, Aaron Maschinot, Ce Liu, and
     of Single Layer Networks in Unsupervised Feature Learn-                  Dilip Krishnan. Supervised contrastive learning. Advances
     ing. In AISTATS, 2011. https://cs.stanford.                              in neural information processing systems, 33:18661–18673,
     edu/˜acoates/papers/coatesleeng_aistats_                                 2020. 2
     2011.pdf. 12                                                        [22] Jonathan Krause, Michael Stark, Jia Deng, and Li Fei-Fei.
 [9] Wenliang Dai, Junnan Li, Dongxu Li, Anthony Meng Huat                    3d object representations for fine-grained categorization. In
     Tiong, Junqi Zhao, Weisheng Wang, Boyang Li, Pascale                     4th International IEEE Workshop on 3D Representation and
     Fung, and Steven Hoi. Instructblip: Towards general-                     Recognition (3dRR-13), Sydney, Australia, 2013. 1, 4, 12
     purpose vision-language models with instruction tuning,             [23] Alex Krizhevsky. Learning multiple layers of features from
     2023. 1, 2                                                               tiny images. Technical report, 2009. 12
[10] Jia Deng, Wei Dong, Richard Socher, Li-Jia Li, Kai Li,              [24] Yann LeCun, Corinna Cortes, and CJ Burges. Mnist hand-
     and Li Fei-Fei. Imagenet: A large-scale hierarchical image               written digit database. ATT Labs [Online]. Available:
     database. In 2009 IEEE conference on computer vision and                 http://yann.lecun.com/exdb/mnist, 2, 2010. 12
     pattern recognition, pages 248–255. Ieee, 2009. 4, 5, 12            [25] Dongjun Lee, Seokwon Song, Jihee Suh, Joonmyeong Choi,
[11] Dheeru Dua, Yizhong Wang, Pradeep Dasigi, Gabriel                        Sanghyeok Lee, and Hyunwoo J. Kim. Read-only prompt
     Stanovsky, Sameer Singh, and Matt Gardner. DROP: A read-                 optimization for vision-language few-shot learning. In
     ing comprehension benchmark requiring discrete reasoning                 Proceedings of the IEEE/CVF International Conference on
     over paragraphs. In Proc. of NAACL, 2019. 8                              Computer Vision (ICCV), 2023. 2, 3
[12] Li Fei-Fei, Rob Fergus, and Pietro Perona. Learning gener-          [26] Brian Lester, Rami Al-Rfou, and Noah Constant. The power
     ative visual models from few training examples: An incre-                of scale for parameter-efficient prompt tuning. arXiv preprint
     mental bayesian approach tested on 101 object categories.                arXiv:2104.08691, 2021. 2
     Computer Vision and Pattern Recognition Workshop, 2004.             [27] Zhiqiu Lin, Xinyue Chen, Deepak Pathak, Pengchuan
     12                                                                       Zhang, and Deva Ramanan. Visualgptscore: Visio-linguistic
[13] Andreas Geiger, Philip Lenz, and Raquel Urtasun. Are we                  reasoning with multimodal generative pre-training scores.
     ready for autonomous driving? the kitti vision benchmark                 arXiv preprint arXiv:2306.01879, 2023. 2, 5


                                                                     9
[28] Haotian Liu, Chunyuan Li, Yuheng Li, and Yong Jae Lee.                     pages 1631–1642, Seattle, Washington, USA, 2013. Associ-
     Improved baselines with visual instruction tuning, 2023. 5                 ation for Computational Linguistics. 12
[29] Haotian Liu, Chunyuan Li, Qingyang Wu, and Yong Jae Lee.              [43] Johannes Stallkamp, Marc Schlipsing, Jan Salmen, and
     Visual instruction tuning. arXiv preprint arXiv:2304.08485,                Christian Igel. Man vs. computer: Benchmarking machine
     2023. 1, 2, 4, 5                                                           learning algorithms for traffic sign recognition. Neural net-
[30] Xiao Liu, Kaixuan Ji, Yicheng Fu, Weng Lam Tam, Zhengx-                    works, 32:323–332, 2012. 12
     iao Du, Zhilin Yang, and Jie Tang. P-tuning v2: Prompt                [44] Ximeng Sun, Pengchuan Zhang, Peizhao Zhang, Hardik
     tuning can be comparable to fine-tuning universally across                 Shah, Kate Saenko, and Xide Xia. Dime-fm : Distilling mul-
     scales and tasks. arXiv preprint arXiv:2110.07602, 2021. 2                 timodal and efficient foundation models. In Proceedings of
[31] Subhransu Maji, Esa Rahtu, Juho Kannala, Matthew                           the IEEE/CVF International Conference on Computer Vision
     Blaschko, and Andrea Vedaldi. Fine-grained visual classi-                  (ICCV), pages 15521–15533, 2023. 3, 4
     fication of aircraft. arXiv preprint arXiv:1306.5151, 2013.           [45] Mirac Suzgun, Nathan Scales, Nathanael Schärli, Sebastian
     4, 12                                                                      Gehrmann, Yi Tay, Hyung Won Chung, Aakanksha Chowd-
[32] Yuval Netzer, Tao Wang, Adam Coates, Alessandro Bis-                       hery, Quoc V Le, Ed H Chi, Denny Zhou, , and Jason Wei.
     sacco, Bo Wu, and Andrew Y Ng. Reading digits in natural                   Challenging big-bench tasks and whether chain-of-thought
     images with unsupervised feature learning. 2011. 13                        can solve them. arXiv preprint arXiv:2210.09261, 2022. 8
[33] M-E. Nilsback and A. Zisserman. Automated flower classi-              [46] Bart Thomee, David A Shamma, Gerald Friedland, Ben-
     fication over a large number of classes. In Proceedings of the             jamin Elizalde, Karl Ni, Douglas Poland, Damian Borth, and
     Indian Conference on Computer Vision, Graphics and Image                   Li-Jia Li. Yfcc100m: The new data in multimedia research.
     Processing, 2008. 12                                                       Communications of the ACM, 59(2):64–73, 2016. 12
                                                                           [47] Yonglong Tian, Dilip Krishnan, and Phillip Isola. Con-
[34] Aaron van den Oord, Yazhe Li, and Oriol Vinyals. Repre-
                                                                                trastive multiview coding. In Computer Vision–ECCV 2020:
     sentation learning with contrastive predictive coding. arXiv
                                                                                16th European Conference, Glasgow, UK, August 23–28,
     preprint arXiv:1807.03748, 2018. 2
                                                                                2020, Proceedings, Part XI 16, pages 776–794. Springer,
[35] R OpenAI. Gpt-4 technical report. arXiv, pages 2303–
                                                                                2020. 2
     08774, 2023. 1, 2
                                                                           [48] Hugo Touvron, Louis Martin, Kevin Stone, Peter Albert,
[36] O. M. Parkhi, A. Vedaldi, A. Zisserman, and C. V. Jawahar.                 Amjad Almahairi, Yasmine Babaei, Nikolay Bashlykov,
     Cats and dogs. In IEEE Conference on Computer Vision and                   Soumya Batra, Prajjwal Bhargava, Shruti Bhosale, et al.
     Pattern Recognition, 2012. 13                                              Llama 2: Open foundation and fine-tuned chat models. arXiv
[37] Wang Qi, Yu-Ping Ruan, Yuan Zuo, and Taihao Li.                            preprint arXiv:2307.09288, 2023. 1, 2, 3
     Parameter-efficient tuning on layer normalization for pre-            [49] Ashish Vaswani, Noam Shazeer, Niki Parmar, Jakob Uszko-
     trained language models. arXiv preprint arXiv:2211.08682,                  reit, Llion Jones, Aidan N Gomez, Łukasz Kaiser, and Illia
     2022. 8                                                                    Polosukhin. Attention is all you need. Advances in neural
[38] Alec Radford, Jong Wook Kim, Chris Hallacy, Aditya                         information processing systems, 30, 2017. 2
     Ramesh, Gabriel Goh, Sandhini Agarwal, Girish Sastry,                 [50] Shijie Wu, Ozan Irsoy, Steven Lu, Vadim Dabravolski, Mark
     Amanda Askell, Pamela Mishkin, Jack Clark, et al. Learning                 Dredze, Sebastian Gehrmann, Prabhanjan Kambadur, David
     transferable visual models from natural language supervi-                  Rosenberg, and Gideon Mann. Bloomberggpt: A large lan-
     sion. In International conference on machine learning, pages               guage model for finance. arXiv preprint arXiv:2303.17564,
     8748–8763. PMLR, 2021. 1, 2, 3, 4, 5, 12                                   2023. 2
[39] Christoph Schuhmann, Richard Vencu, Romain Beaumont,                  [51] Guangxuan Xiao, Yuandong Tian, Beidi Chen, Song Han,
     Robert Kaczmarczyk, Clayton Mullis, Aarush Katta, Theo                     and Mike Lewis. Efficient streaming language models with
     Coombes, Jenia Jitsev, and Aran Komatsuzaki. Laion-400m:                   attention sinks. arXiv preprint arXiv:2309.17453, 2023. 4
     Open dataset of clip-filtered 400 million image-text pairs.           [52] J. Xiao, J. Hays, K. A. Ehinger, A. Oliva, and A. Tor-
     arXiv preprint arXiv:2111.02114, 2021. 5, 12                               ralba. Sun database: Large-scale scene recognition from
[40] Piyush Sharma, Nan Ding, Sebastian Goodman, and Radu                       abbey to zoo. In 2010 IEEE Computer Society Conference
     Soricut. Conceptual captions: A cleaned, hypernymed, im-                   on Computer Vision and Pattern Recognition, pages 3485–
     age alt-text dataset for automatic image captioning. In Pro-               3492, 2010. 12
     ceedings of ACL, 2018. 5, 12                                          [53] Jianwei Yang, Chunyuan Li, Pengchuan Zhang, Bin Xiao, Ce
[41] Karan Singhal, Shekoofeh Azizi, Tao Tu, S Sara Mahdavi,                    Liu, Lu Yuan, and Jianfeng Gao. Unified contrastive learning
     Jason Wei, Hyung Won Chung, Nathan Scales, Ajay Tan-                       in image-text-label space. In Proceedings of the IEEE/CVF
     wani, Heather Cole-Lewis, Stephen Pfohl, et al. Large                      Conference on Computer Vision and Pattern Recognition,
     language models encode clinical knowledge. Nature, 620                     pages 19163–19173, 2022. 6, 13
     (7972):172–180, 2023. 2                                               [54] Xiaohua Zhai, Joan Puigcerver, Alexander Kolesnikov,
[42] Richard Socher, Alex Perelygin, Jean Wu, Jason Chuang,                     Pierre Ruyssen, Carlos Riquelme, Mario Lucic, Josip Djo-
     Christopher D. Manning, Andrew Ng, and Christopher Potts.                  longa, Andre Susano Pinto, Maxim Neumann, Alexey Doso-
     Recursive deep models for semantic compositionality over                   vitskiy, Lucas Beyer, Olivier Bachem, Michael Tschannen,
     a sentiment treebank. In Proceedings of the 2013 Confer-                   Marcin Michalski, Olivier Bousquet, Sylvain Gelly, and Neil
     ence on Empirical Methods in Natural Language Processing,                  Houlsby. The visual task adaptation benchmark. 2019. 12


                                                                      10
[55] Xiaohua Zhai, Xiao Wang, Basil Mustafa, Andreas Steiner,
     Daniel Keysers, Alexander Kolesnikov, and Lucas Beyer.
     Lit: Zero-shot transfer with locked-image text tuning. In
     Proceedings of the IEEE/CVF Conference on Computer Vi-
     sion and Pattern Recognition, pages 18123–18133, 2022. 2,
     4, 5, 6
[56] Xiaohua Zhai, Basil Mustafa, Alexander Kolesnikov, and
     Lucas Beyer. Sigmoid loss for language image pre-training.
     arXiv preprint arXiv:2303.15343, 2023. 2
[57] Susan Zhang, Stephen Roller, Naman Goyal, Mikel Artetxe,
     Moya Chen, Shuohui Chen, Christopher Dewan, Mona Diab,
     Xian Li, Xi Victoria Lin, Todor Mihaylov, Myle Ott, Sam
     Shleifer, Kurt Shuster, Daniel Simig, Punit Singh Koura, An-
     jali Sridhar, Tianlu Wang, and Luke Zettlemoyer. Opt: Open
     pre-trained transformer language models, 2022. 8
[58] Lianmin Zheng, Wei-Lin Chiang, Ying Sheng, Siyuan
     Zhuang, Zhanghao Wu, Yonghao Zhuang, Zi Lin, Zhuohan
     Li, Dacheng Li, Eric. P Xing, Hao Zhang, Joseph E. Gonza-
     lez, and Ion Stoica. Judging llm-as-a-judge with mt-bench
     and chatbot arena, 2023. 2
[59] Deyao Zhu, Jun Chen, Xiaoqian Shen, Xiang Li, and Mo-
     hamed Elhoseiny. Minigpt-4: Enhancing vision-language
     understanding with advanced large language models. arXiv
     preprint arXiv:2304.10592, 2023. 1, 2, 3, 4, 5




                                                                    11
A. Dataset Details                                                   MNIST [24]: MNIST is a dataset of black-and-white hand-
                                                                     written digits, with 10 classes split across 10000 test im-
We detail the datasets used in our paper, both for training          ages.
and evaluation.                                                      RenderedSST2 [38] : RenderedSST2 is contains text ren-
                                                                     dered in images, from the Stanford Sentiment Treebank v2
A.1. Training data                                                   dataset[42]. The sentences are pulled from movie reviews,
We use the following image-text datasets for pre-training:           and the task is a binary classification into positive and neg-
Conceptual Captions 3M [40]: A dataset of 3.3 million                ative sentiment movies. There are 1821 samples in the test
images, with the text captions being HTML alt-text. Both             set.
images and text are filtered to retain high quality images.          STL10 [8]: STL10 is a natural image dataset of 96x96 im-
Conceptual Captions 12M [2]: A larger-scale version of               ages in 10 classes. There 800 images per-class for a total of
Conceptual Captions 3M, containing 10 million images.                8000 test images.
The image and text filter used for collecting Conceptual             SUN397 [52]: SUN397 is a natural image dataset of scenes,
Captions 3 million are made less strict, allowing for a nois-        instead of objects. For example, labels include “airport ter-
ier yet larger dataset.                                              minal” and “jewlery shop”. The evaluation set is balanced,
LAION-200M[39]: We subsample the LAION-400M                          and contains 50 samples per class for a total of 19850 im-
dataset uniformly and at random, collecting a total of               ages.
264662608 samples, due to downloading failures and dead              Caltech101 [12]: Caltech101 is a natural image dataset of
links. The LAION-400M scrapes the Common Crawl                       101 classes and a background class, each labelled with a
dataset, and filters out samples which are too dissimilar ac-        single object. There are 6085 test samples.
cording to a cosine-similarity computed using an OpenAI              CIFAR-10 [23]: CIFAR-10 is a natural image dataset of
CLIP model.                                                          32x32 images, with each sample belonging to one of ten
ImageNet-21K [10] ImageNet-22k is the full ImageNet-                 classes. There are 10000 samples.
21k dataset, with ImageNet-1k classes removed to fairly              CIFAR-100 [23]:Similar to CIFAR-100 but with more
evaluate the zero-shot capabilities of trained models on the         classes, CIFAR-100 is a natural image dataset of 32x32 im-
ImageNet-1k dataset.                                                 ages, with each sample belonging to one of one hundred
                                                                     classes. There are 10000 samples.
A.2. Evaluation Datasets                                             CLEVR Distance [19]: A synthetic dataset of objects,
                                                                     where the task is a 5 way classification of distances la-
Below we describe the zero-shot evaluation dataset we use            bels “{”’very nearby’, ’nearby’, ’near’, ’distant’, ’very dis-
for evaluation.                                                      tant’}”, which correspond to the distance of the closest ob-
ImageNet 1k[10]: ImageNet1k is a natural image dataset               ject. There are 15000 test samples.
consisting of 1000 object classes, evenly distributed over           CLEVR Count [19]: A synthetic dataset of objects, where
50,000 images.                                                       the task is an 8 way classification of labels, corresponding
Stanford Cars[22]: The Stanford cars dataset contains                to object counting. There are 15000 test samples, which are
8041 test images, over 196 classes of cars. Each class is            the same as for the CLEVR distance classification task.
a Make, Model, Year combination, for example “Hyundai                Diabetic Retinopathy [20]: This dataset is a medical imag-
Veloster Hatchback 2012”. Some distinctions are quite fine           ing dataset of retinas, with a 5 way classificaiton problem
grained; for example “Aston Martin V8 Vantage Convert-               corresponding to the severity of the diabetic retinopathy
ible 2012” versus “Aston Martin V8 Vantage Coupe 2012”.              present in the image. There are 42670 test images.
Country211 [38]: Country211 is a subset of YFCC100M                  DMLAB [54]: DMLAB consists of synthetic images, and
[46] to find geotagged images from 211 countries. The                there are 6 classes, consisting of positive rewards(apples
dataset is balanced across classes, with 100 samples from            and melons) or negative rewards(lemons), each of which
each class.                                                          can be nearby, far, or very far. There are 22735 test images.
FGVC Aircraft [31]: The aircraft dataset contains 3333               Describable Textures [7]: Describable Textures is 1880
test images divided across 100 aircraft models e.g. 777-300          test images of textures, divided into 47 classes. Class labels
or DC-10. It’s very fine-grained, the differences between            are labelled with texture descriptions such as “wrinkled”,
differnt generations of the same aircraft (747-300 vs 747-           “marbled”, or “braided”.
400) are quite subtle.                                               EuroSAT [14]: EuroSAT contains images of sattelite im-
GTSRB [43]: GTSRB is a classificatio benchmark of                    agery, split into 10 classes of land use like “forest” or “pas-
Germa Traffic Signs into classes like “red and white cir-            ture land”. The test set contains 5400 samples.
cle 20 kph speed limit”. There are 12630 evaluation images           Oxford Flowers [33]: Oxford Flowers is a dataset of flower
and 43 classes.                                                      species; with 102 classes and 6149 samples.


                                                                12
                                                                        1 import pandas as pd
                                          Learned                       2 import spacy
                      Text input          Prompts                       3 from tqdm import tqdm
                                                                        4 import pickle
                                                                        5
                                                                        6 nlp = spacy.load("en_core_web_sm", disable=[’ner’
                                                                              , ’lemmatizer’, ’textcat’])
                                                                        7 dataset = pd.read_csv(’cc12m.tsv’, delimiter=’\t’
 Text input                                                                   )
                                                                        8
                                                                        9 concept_dict = {}
                                                                       10 for i, txt in tqdm(enumerate(nlp.pipe(iter(
                                                                              dataset[’caption’])))):
                                                                       11     for n in txt.noun_chunks:
   Learned                                                             12         chunk = str(n).lower().strip()
                                                                                  concept_dict[chunk] = concept_dict.get(
   Prompts                                                             13
                                                                              chunk, 0) + 1
                                                                       14
                                                                       15   with open(’concept_dict.pkl’, ’wb’) as handle:
                                                                       16       pickle.dump(concept_dict, handle)
                                                                       17
Figure 4. Read only prompts. The attention we use. The Learned
Prompts can attend to all positions in the sequence, while text to-
kens can only attend to tokens in positions before.                         Figure 5. Generating Pre-training Concept Dictionaries. We it-
                                                                            erate through captions in the pre-training data, use spaCy to extract
                                                                            noun chunks, and populate a dictionary.
KITTI [13]: KITTI consists of test images divided into
four classes {’a photo i took of a car on my left or right
side.’,’a photo i took with a car nearby. ’,’a photo i took                 C. Training Details
with a car in the distance. ’,’a photo i took with no car.’},               We build on top of OpenCLIP[18], and provide hyperpa-
corresponding to the distance of the closest car in photos                  rameters in Table 6.
taken from the persepctive of a car driver.
PatchCamelyon [? ]: PatchCamelyon is a challenging                          D. Coverage Analysis
dataset of microscope slide images, split evenly between
cancerous and non-cancerous samples. There are 32768 test                   D.1. Pseudocode
images.                                                                     We generate concept count dictionaries by counting the fre-
Oxford-IIT Pets [36]: 3669 test images of cats and dogs,                    quency of noun-chunks in the pre-training data, following
split into 37 classes pertaining to different breeds.                       UniCL [53]. Then, we extract noun-chunks from class
Resisc45[4]: A satellite imagery dataset, with 45 classes                   labels in target datasets and count the frequency of noun
which are mixture of natural (e.g. ‘mountain’) and man-                     chunks present in the pretraining data. We only consider
made (‘harbor’) classes. There are a total of 6300 evaluation               a label present in the pre-training data if a noun-chunk is
images.                                                                     present more than 5 times. We then compute two met-
SVHN[32]: This is a dataset testing OCR capabilities.                       rics: what percentage of target labels are present in the pre-
There are ten classes, corresponding to ten digits. The im-                 training (coverage) and how many times the noun chunks
ages are 32x32 and are cropposed house numbers. There                       present in the target class label list are present in the pre-
are 26,032 test images.                                                     training data. We show pseudo-code for constructing con-
                                                                            ception dictionary from pre-training data (Figure 5) and
B. Read Only Prompts Attention Mask                                         computing count and coverage (Figure 6).

In this section, we illustrate the Attention Mask of the Read-              D.2. Statistics for other pre-training datasets
Only prompts. As we discuss in the main paper, causal                       In the main paper, we compute coverage and count statis-
attention masks mean that tokens appended to the end of                     tics for LAION-200M, but we also pretrain on ImageNet-
an input sequence can only attend to tokens coming before                   21k, CC3M, and CCM12M. Therefore, we provide statis-
them. In the case of read-only prompts, this is desirable                   tics below. As one can see, overall the statistics are heavily
in order to not shift the representations of the text tokens                correlated for all the datasets.
while learning the soft tokens. We additionally modify the
attention mask as illustrated in Figure 4, such that read-only
prompts can attend to each other as well.                                      1 https://huggingface.co/lmsys/vicuna-13b-v1.5




                                                                      13
             Parameter                         Value                                                     Parameter                             Value
         Text Encoder Arch.               CLIP ViT-B-16                                              Text Encoder Arch.                     Vicuna 13B
          Text Encoder Init.                 Random                                                   Text Encoder Init.                    lmsys-1.51
        Vision Encoder Arch.                 ViT-B-16                                               Vision Encoder Arch.                     ViT-B-16
        Vision Encoder Init.            openclip, laion400m                                         Vision Encoder Init.                openclip, laion400m
              Batch Size                        8192                                                      Batch Size                            8192
              Optimizer                      AdamW                                                        Optimizer                          AdamW
            Learning Rate                     0.0005                                                    Learning Rate                         0.0005
            Weight Decay                         0.5                                                    Weight Decay                             0.5
           Training Steps                      59317                                                   Training Steps                          59317
           Warmup Steps                         1220                                                   Warmup Steps                             1220
       Learning Rate Schedule                  cosine                                              Learning Rate Schedule                      cosine
       Num Learnable Prompts                     n/a                                               Num Learnable Prompts                         24
             LoRA Rank                           n/a                                                     LoRA Rank                               16
           LoRA dropout                          n/a                                                   LoRA dropout                              0.1
             LoRA alpha                          n/a                                                     LoRA alpha                              16
       Gradient Clipping Norm                     1                                                Gradient Clipping Norm                         1
                   (a) LiT Training Hyperparameters                                                          (b) CLAMP training hyperparameters

                                                             Table 6. Training hyperparameters.




                                                                                                                                                      athy




                                                                                                                                                  ance
                                                                                                                                                  nop
                                                                                                                                                  on
                                                                                                                                                   ft




                                                                                                                                                 T2



                                                                                                                                                  nt
                                                                                                                                             ircra

                                                                                                                                                y
                                                                                                                                             Reti




                                                                                                                                             Dist

                                                                                                                                             Cou
                                                                                                                 k




                                                                                                                                            dSS
                                                                                                                                            mel
                                                   11




                                                                                                            et 1
                                                                             100

                                                                                      01
                                                             10
                                                      2
                                  SAT




                                                                                                                                        CA
                                                                                             5




                                                                                                                                       LAB
                                                                                    ech1




                                                                                                                                        etic


                                                                                                                                       dere
                                                                                                                                       hCa
                                                 ntry




                                                                                                                                        VR

                                                                                                                                        VR
                                                                    B




                                                                                                       geN
                                                                                                        ers
                                                                                            isc4




                                                                                                                                       IST
                                                                                                       397
                                                             AR




                                                                             AR
                                         10




                                                                                                                                        N
                                                                      R




                                                                                                                            DTD
                                                                                                   Flow




                                                                                                                                  FGV




                                                                                                                                   SVH
                                Euro




                                                                                                                                   Diab
                                                                  GTS




                                                                                                                                   CLE

                                                                                                                                   CLE
                          i




                                                                                                                     Cars
                                        STL




                                                                                                                                   Patc
                                              Cou




                                                                                   Calt




                                                                                                   Pets




                                                                                                                                   MN

                                                                                                                                   Ren




                                                                                                                                   DM
                        Kitt




                                                          CIF




                                                                          CIF




                                                                                                   Sun

                                                                                                   Ima
                                                                                           Res




Pretraining Data Metric
LAION-200M Coverage 1.00 0.70 1.00 0.96 1.00 0.47 0.76 0.77 0.47 0.67 0.65 0.82 0.86 0.47 0.13 0.38 1.00 0.20 0.00 0.00 0.00 0.00 0.00 0.00
                 Count 2101.5k 24.5k 23.5k 22.2k 17.6k 17.3k 14.3k 7.8k 5.9k 3.9k 3.7k 2.5k 503 432 219 172 18 2     0    0    0    0    0    0
CC3M            Coverage 1.00 0.60 1.00 0.06 1.00 0.44 0.72 0.58 0.47 0.16 0.44 0.41 0.11 0.05 0.04 0.06 0.00 0.00 0.00 0.00 0.00 0.00 0.00 0.00
                 Count 83.6k 2.8k 2.2k 121 1.9k 21.9k 2.1k 416 730 95 190 158 47 2                   2 42 0     0    0    0    0 0       0    0
CC12M           Coverage 1.00 0.70 1.00 0.86 1.00 0.44 0.76 0.72 0.47 0.38 0.58 0.70 0.73 0.24 0.06 0.19 0.00 0.00 0.00 0.00 0.00 0.00 0.00 0.00
                 Count 373.0k 3.6k 5.1k 2.4k 4.5k 224.2k 2.8k 1.2k 1.0k 486 671 361 120 134 15 152 0             0    0    0    0    0    0    0
IM-21k          Coverage 1.00 0.10 1 .00 0.07 1.00 0.14 0.62 0.45 0.27 0.34 0.29 0.13 0.05 0.03 0.04 0.01 0.00 0.00 0.00 0.00 0.00 0.00 0.00 0.00
                 Count   650    65 1.5k 74 1.3k 423 715 452 217 300 247 130 35 27 28 7                       0  0    0    0    0    0    0    0

Table 7. Pretraining Coverage and Count Statistics. We compute coverage and count statistics for our other pre-training datasets, in
addition to LAION-200M. We find that these statistics follow similar trends in LAION-200M,CC3M, CC12M, and ImageNet-21k.




                                                                                    14
 1
 2 import spacy
 3 from tqdm import tqdm
 4 import pickle
 5
 6   nlp = spacy.load("en_core_web_sm", disable=[’ner’
         , ’lemmatizer’, ’textcat’])
 7
 8
 9   def read_file(class_list, dict_loc):
10
11        with open(dict_loc, ’rb’) as f:
12            concept_dict = pickle.load(f)
13
14
15        coverage = 0
16        count = 0
17        num_classes = 0
18        try:
19             with open(class_list, ’r’) as file:
20                 for line in file:
21                     l = line.strip().lower()
22                     noun_chunks = nlp(l).noun_chunks
23                     local_count = 0
24                     present = 0
25                     for c in noun_chunks:
26                         count = concept_dict[c]
27                         if chunk_count > 5:
28                             local_count += count
29                             present = 1
30                         else:
31                             local_count += 0
32
33                    coverage += present
34                    count += local_count
35                    num_classes += 1
36            print(’Coverage: {}’.format(coverage/
          num_classes))
37            print(’Count: {}’.format(count/
          num_classes))
38




     Figure 6. Generating Concept Count and Coverage. Pseudo-
     code for computing coverage and count statistics for a target
     dataset. We iterate through target classnames, extract noun chunks
     using spaCy, and check for their presence in the dictionary com-
     puted in Figure 5.




                                                                          15
