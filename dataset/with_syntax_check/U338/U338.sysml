package 'Oragene DNA Collection and Preservation System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def SampleIdentifier;
    attribute def Timestamp;
    attribute def QualityScore;

    value def SalivaVolume :> VolumeValue {
        attribute volumeML : Real;
    }

    value def DNAYield {
        attribute yieldMicrograms : Real;
    }

    value def StorageDuration :> DurationValue {
        attribute durationMonths : Real;
    }

    value def RoomTemperature :> ThermodynamicTemperatureValue {
        attribute tempCelsius : Real;
    }

    item def RawSaliva {
        attribute volume : SalivaVolume;
        attribute collectionTimestamp : Timestamp;
        attribute containsCells : Boolean;
    }

    item def StabilizationReagent {
        attribute volume : SalivaVolume;
        attribute pH : Real;
        attribute isActive : Boolean;
    }

    item def StabilizedDNASample {
        attribute sampleID : SampleIdentifier;
        attribute totalVolume : SalivaVolume;
        attribute dnaYield : DNAYield;
        attribute qualityScore : QualityScore;
        attribute stabilizationTimestamp : Timestamp;
        attribute integrityMaintained : Boolean;
    }

    port def SalivaInputPort {
        in item salivaFlow : RawSaliva;
    }

    port def ReagentPort {
        in item reagentFlow : StabilizationReagent;
    }

    port def SampleOutputPort {
        out item stabilizedSampleFlow : StabilizedDNASample;
    }

    part def CollectionFunnel {
        port salivaEntry : SalivaInputPort;
        port salivaExit : SalivaInputPort;
        attribute funnelDiameter : LengthValue;
    }

    part def CollectionTube {
        port tubeInlet : SalivaInputPort;
        attribute tubeCapacity : SalivaVolume;
        attribute currentLevel : SalivaVolume;
        attribute graduationMarks : Boolean;
    }

    part def ReagentReservoir {
        port reagentRelease : ReagentPort;
        attribute reservoirVolume : SalivaVolume;
        attribute reagentConcentration : Real;
    }

    part def MixingChamber {
        port salivaInput : SalivaInputPort;
        port reagentInput : ReagentPort;
        port mixedOutput : SampleOutputPort;
        attribute mixingComplete : Boolean;
    }

    part def SealingCap {
        attribute isSealed : Boolean;
        attribute capIntegrity : Boolean;
        part reagentReservoir : ReagentReservoir;
    }

    part def StorageContainer {
        port samplePort : SampleOutputPort;
        attribute storedSample : StabilizedDNASample;
        attribute storageTemperature : RoomTemperature;
        attribute isSealed : Boolean;
    }

    action def ReceiveSalivaAction {
        in attribute targetVolume : SalivaVolume;
        out attribute collectedSaliva : RawSaliva;
    }

    action def ReleaseReagentAction {
        in attribute reagentDose : SalivaVolume;
        out attribute releasedReagent : StabilizationReagent;
    }

    action def MixSampleAction {
        in attribute saliva : RawSaliva;
        in attribute reagent : StabilizationReagent;
        out attribute mixedSample : StabilizedDNASample;
    }

    action def SealContainerAction {
        in attribute sample : StabilizedDNASample;
        out attribute sealedSample : StabilizedDNASample;
    }

    action def ValidateQualityAction {
        in attribute sample : StabilizedDNASample;
        out attribute qualityPassed : Boolean;
    }

    attribute def StartCollectionSignal;

    state def OrageneCollectionStates {
        entry; then ready;

        state ready {
            doc /* System is ready to receive saliva sample. */
        }
        transition ready_to_collecting
            first ready
            accept StartCollectionSignal
            then collecting;

        state collecting {
            doc /* Actively collecting saliva into tube. */
        }
        transition collecting_to_sealing
            first collecting
            then sealing;

        state sealing {
            doc /* Cap is being closed to seal tube. */
        }
        transition sealing_to_releasing
            first sealing
            then releasingReagent;

        state releasingReagent {
            doc /* Reagent is released from cap reservoir. */
        }
        transition releasing_to_mixing
            first releasingReagent
            then mixing;

        state mixing {
            doc /* Sample and reagent are being mixed. */
        }
        transition mixing_to_stabilized
            first mixing
            then stabilized;

        state stabilized {
            doc /* DNA is stabilized and ready for storage. */
        }
        transition stabilized_to_stored
            first stabilized
            then stored;

        state stored {
            doc /* Sample is stored at room temperature. */
        }
    }

    action def PerformDNACollectionAndStabilization {
        in attribute requiredVolume : SalivaVolume;
        in attribute reagentVolume : SalivaVolume;
        out attribute finalStabilizedSample : StabilizedDNASample;

        first start;
        then merge beginProcess;

        then action receiveSaliva : ReceiveSalivaAction {
            in targetVolume = requiredVolume;
            out collectedSaliva;
        }

        then action releaseReagent : ReleaseReagentAction {
            in reagentDose = reagentVolume;
            out releasedReagent;
        }

        flow receiveSaliva.collectedSaliva to mixSample.saliva;
        flow releaseReagent.releasedReagent to mixSample.reagent;

        then action mixSample : MixSampleAction {
            in saliva;
            in reagent;
            out mixedSample;
        }

        then action sealContainer : SealContainerAction {
            in sample = mixSample.mixedSample;
            out sealedSample;
        }

        then action validateQuality : ValidateQualityAction {
            in sample = sealContainer.sealedSample;
            out qualityPassed;
        }

        then decide;
            if validateQuality.qualityPassed then assignFinal;
            if not validateQuality.qualityPassed then beginProcess;

        action assignFinal {
            assign finalStabilizedSample := validateQuality.sample;
        }
        then done;
    }

    part def OrageneKit {
        attribute kitID : SampleIdentifier;
        attribute expirationDate : Timestamp;

        part funnel : CollectionFunnel {
            attribute funnelDiameter = 25.0 [mm];
        }

        part tube : CollectionTube {
            attribute tubeCapacity = SalivaVolume { volumeML = 5.0; }
            attribute currentLevel = SalivaVolume { volumeML = 0.0; }
            attribute graduationMarks = true;
        }

        part cap : SealingCap {
            attribute isSealed = false;
            attribute capIntegrity = true;
        }

        part mixingChamber : MixingChamber {
            attribute mixingComplete = false;
        }

        part storageContainer : StorageContainer {
            attribute storageTemperature = RoomTemperature { tempCelsius = 22.0; }
            attribute isSealed = false;
        }

        connection funnelToTube
            connect funnel.salivaExit to tube.tubeInlet;

        connection tubeToMixing
            connect tube to mixingChamber.salivaInput;

        connection capToMixing
            connect cap.reagentReservoir.reagentRelease to mixingChamber.reagentInput;

        connection mixingToStorage
            connect mixingChamber.mixedOutput to storageContainer.samplePort;

        perform action collectionProcess : PerformDNACollectionAndStabilization {
            in requiredVolume = SalivaVolume { volumeML = 2.0; }
            in reagentVolume = SalivaVolume { volumeML = 2.0; }
            out finalStabilizedSample;
        }
    }

    requirement def DNAStabilizationCapability {
        doc /* The Oragene system shall stabilize DNA in saliva samples 
               for long-term storage at ambient room temperature without 
               refrigeration for a minimum of 60 months. */

        subject kit : OrageneKit;

        require constraint {
            kit.storageContainer.storedSample.integrityMaintained == true
        }
    }

    requirement def MinimumSampleVolumeReq {
        doc /* The system shall collect and process a minimum of 2.0 mL 
               of saliva to ensure adequate DNA yield for genetic analysis. */

        subject kit : OrageneKit;

        require constraint {
            kit.tube.currentLevel.volumeML >= 2.0
        }
    }

    requirement def RoomTemperatureStorage {
        doc /* The system shall maintain DNA stability at room temperature 
               between 15°C and 30°C without requiring cold chain logistics. */

        subject container : StorageContainer;

        require constraint {
            container.storageTemperature.tempCelsius >= 15.0 and
            container.storageTemperature.tempCelsius <= 30.0
        }
    }

    requirement def NonInvasiveCollection {
        doc /* The system shall provide a non-invasive, self-collection 
               method suitable for use without medical supervision. */

        subject kit : OrageneKit;
    }

    requirement def ContaminationPrevention {
        doc /* The system shall prevent external contamination through 
               sealed container design and integrated reagent delivery. */

        subject kit : OrageneKit;

        require constraint {
            kit.cap.isSealed == true and
            kit.storageContainer.isSealed == true
        }
    }

    requirement def DNAYieldRequirement {
        doc /* The system shall yield a minimum of 110 micrograms of DNA 
               from a 2 mL saliva sample for downstream genetic analysis. */

        subject sample : StabilizedDNASample;

        require constraint {
            sample.dnaYield.yieldMicrograms >= 110.0
        }
    }

    requirement orageneSystemRequirement {
        doc /* The Oragene DNA Collection and Preservation System shall 
               provide a complete solution for non-invasive collection, 
               stabilization, and long-term ambient storage of high-quality 
               DNA from human saliva samples for genetic testing and research. */

        subject orageneDevice : OrageneKit;
    }

    part orageneDevice : OrageneKit {
        attribute kitID = "ORG-DNA-2024-001";
        attribute expirationDate = "2026-12-31";

        satisfy orageneSystemRequirement by orageneDevice;
    }
}
