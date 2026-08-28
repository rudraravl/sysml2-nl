package SengstakenBlakemoreTubeSystem {
    private import ScalarValues::*;
    
    attribute def Pressure :> Real;
    attribute def Volume :> Real;
    attribute def Length :> Real;
    
    item def Air;
    item def Fluid;
    item def Blood :> Fluid;
    
    port def InflationPort {
        attribute pressure : Pressure;
        in item air : Air;
    }
    
    port def SuctionPort {
        out item fluid : Fluid;
    }
    
    part def SengstakenBlakemoreTube {
        attribute tubeLength : Length = 1.0;
        attribute material : String = "Medical-grade silicone";
        attribute inflateGastricCommand : Boolean = false;
        attribute inflateEsophagealCommand : Boolean = false;
        attribute deflateCommand : Boolean = false;
        
        port gastricInflationPort : InflationPort;
        port esophagealInflationPort : InflationPort;
        port gastricSuctionPort : SuctionPort;
        port esophagealSuctionPort : SuctionPort;
        
        part mainTubeBody;
        part gastricBalloon {
            attribute maxVolume : Volume = 500.0;
            attribute maxPressure : Pressure = 60.0;
            attribute currentVolume : Volume = 0.0;
            attribute currentPressure : Pressure = 0.0;
        }
        part esophagealBalloon {
            attribute maxVolume : Volume = 200.0;
            attribute maxPressure : Pressure = 45.0;
            attribute currentVolume : Volume = 0.0;
            attribute currentPressure : Pressure = 0.0;
        }
        part gastricAspirationLumen;
        part esophagealAspirationLumen;
        
        perform action inflateGastricBalloon;
        perform action inflateEsophagealBalloon;
        perform action deflateBalloons;
        perform action aspirateGastricContents;
        perform action aspirateEsophagealContents;
        
        exhibit state operationalStates {
            state deflated;
            state inflatingGastric;
            state maintainingGastricTraction;
            state inflatingEsophageal;
            state maintainingPressure;
            state deflating;
            
            transition t1 {
                source deflated;
                target inflatingGastric;
                guard { inflateGastricCommand; }
            }
            transition t2 {
                source inflatingGastric;
                target maintainingGastricTraction;
                guard { gastricBalloon.currentPressure > 0.0; }
            }
            transition t3 {
                source maintainingGastricTraction;
                target inflatingEsophageal;
                guard { inflateEsophagealCommand; }
            }
            transition t4 {
                source inflatingEsophageal;
                target maintainingPressure;
                guard { esophagealBalloon.currentPressure > 0.0; }
            }
            transition t5 {
                source maintainingPressure;
                target deflating;
                guard { deflateCommand; }
            }
            transition t6 {
                source deflating;
                target deflated;
                guard { gastricBalloon.currentVolume == 0.0 and esophagealBalloon.currentVolume == 0.0; }
            }
        }
    }
    
    action def inflateGastricBalloon {
        doc /* Inflate the gastric balloon to achieve mechanical tamponade in the stomach. */
    }
    action def inflateEsophagealBalloon {
        doc /* Inflate the esophageal balloon after gastric anchoring to compress esophageal varices. */
    }
    action def deflateBalloons {
        doc /* Deflate both balloons sequentially for safe device removal. */
    }
    action def aspirateGastricContents {
        doc /* Suction blood and fluids from the stomach via the gastric aspiration lumen. */
    }
    action def aspirateEsophagealContents {
        doc /* Suction blood and fluids from the esophagus via the esophageal aspiration lumen. */
    }
    
    part def Syringe {
        port outputPort : InflationPort;
    }
    
    part def SuctionLine {
        port inputPort : SuctionPort;
    }
    
    part def Patient {
        part stomach {
            attribute appliedPressure : Pressure;
            ref item blood : Blood;
        }
        part esophagus {
            attribute appliedPressure : Pressure;
            ref item blood : Blood;
        }
    }
    
    part def MedicalContext {
        part sbt : SengstakenBlakemoreTube;
        ref patient : Patient;
        part gastricSyringe : Syringe;
        part esophagealSyringe : Syringe;
        part gastricSuctionLine : SuctionLine;
        part esophagealSuctionLine : SuctionLine;
        
        connect gastricSyringe.outputPort to sbt.gastricInflationPort;
        connect esophagealSyringe.outputPort to sbt.esophagealInflationPort;
        connect gastricSuctionLine.inputPort to sbt.gastricSuctionPort;
        connect esophagealSuctionLine.inputPort to sbt.esophagealSuctionPort;
        
        bind patient.stomach.appliedPressure = sbt.gastricBalloon.currentPressure;
        bind patient.esophagus.appliedPressure = sbt.esophagealBalloon.currentPressure;
        
        flow of Blood from patient.stomach.blood to sbt.gastricSuctionPort.fluid;
        flow of Blood from patient.esophagus.blood to sbt.esophagealSuctionPort.fluid;
    }
    
    requirement def PressureSafetyRequirement {
        subject sbt : SengstakenBlakemoreTube;
        requirement gastricPressureLimit {
            constraint { sbt.gastricBalloon.currentPressure <= 60.0 }
        }
        requirement esophagealPressureLimit {
            constraint { sbt.esophagealBalloon.currentPressure <= 45.0 }
        }
    }
    
    requirement def InflationSequenceRequirement {
        subject sbt : SengstakenBlakemoreTube;
        doc /* The gastric balloon must be inflated and anchored with traction before the esophageal balloon is inflated. */
    }
    
    requirement def TubeSpecificationRequirement {
        subject sbt : SengstakenBlakemoreTube;
        requirement tubeLengthSpec {
            constraint { sbt.tubeLength == 1.0 }
        }
        requirement tubeMaterialSpec {
            constraint { sbt.material == "Medical-grade silicone" }
        }
    }
    
    requirement def BalloonVolumeRequirement {
        subject sbt : SengstakenBlakemoreTube;
        requirement gastricVolumeSpec {
            constraint { sbt.gastricBalloon.maxVolume <= 500.0 }
        }
        requirement esophagealVolumeSpec {
            constraint { sbt.esophagealBalloon.maxVolume <= 200.0 }
        }
    }
    
    requirement def AspirationFunctionRequirement {
        subject sbt : SengstakenBlakemoreTube;
        doc /* Gastric and esophageal aspiration lumens must allow suction of fluids to monitor bleeding and prevent aspiration. */
    }
}
