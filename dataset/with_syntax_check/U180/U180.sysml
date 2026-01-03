package CannulaDeliverySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FluidType;
    attribute def MaterialType;
    attribute def SterilityStatus;
    
    attribute def FlowRateValue :> ISQ::VolumetricFlowRateValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def LengthValue :> ISQ::LengthValue;
    attribute def DiameterValue :> LengthValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    
    item def MedicalFluid {
        attribute fluidType : FluidType;
        attribute viscosity : Real;
        attribute temperature : TemperatureValue;
    }
    
    item def BiologicalTissue {
        attribute tissueType : String;
        attribute penetrationDepth : LengthValue;
    }
    
    port def FluidInputPort {
        in item fluid : MedicalFluid;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }
    
    port def FluidOutputPort {
        out item fluid : MedicalFluid;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }
    
    port def TissueContactPort {
        out item tissue : BiologicalTissue;
        attribute insertionDepth : LengthValue;
    }
    
    part def CannulaTip {
        attribute tipAngle : Real;
        attribute sharpness : Real;
        port tissueInterface : TissueContactPort;
    }
    
    part def CannulaShaft {
        attribute length : LengthValue;
        attribute outerDiameter : DiameterValue;
        attribute innerDiameter : DiameterValue;
        attribute material : MaterialType;
        
        assert constraint validDiameters {
            outerDiameter > innerDiameter
        }
    }
    
    part def CannulaHub {
        attribute hubType : String;
        attribute lockingMechanism : String;
        port fluidInlet : FluidInputPort;
    }
    
    part def Cannula {
        attribute gaugeSize : Real;
        attribute sterility : SterilityStatus;
        
        part tip : CannulaTip;
        part shaft : CannulaShaft;
        part hub : CannulaHub;
        
        port fluidIn : FluidInputPort;
        port fluidOut : FluidOutputPort;
        port tissueContact : TissueContactPort;
        
        connection hubToInternal connect hub.fluidInlet to fluidIn;
        connection internalToTip connect fluidIn to fluidOut;
        connection tipToTissue connect tip.tissueInterface to tissueContact;
    }
    
    part def FluidReservoir {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        item storedFluid : MedicalFluid;
        port fluidOutput : FluidOutputPort;
    }
    
    part def FlowController {
        attribute targetFlowRate : FlowRateValue;
        attribute maxPressure : PressureValue;
        port fluidInput : FluidInputPort;
        port fluidOutput : FluidOutputPort;
    }
    
    part def PressureSensor {
        attribute currentPressure : PressureValue;
        attribute alarmThreshold : PressureValue;
        port monitoringPort : FluidInputPort;
    }
    
    part def Patient {
        attribute patientID : String;
        item targetTissue : BiologicalTissue;
        port deliveryPoint : TissueContactPort;
    }
    
    action def PrepareSystem {
        in cannula : Cannula;
        in reservoir : FluidReservoir;
        out systemReady : Boolean;
        
        first start;
        then action verifySterility {
            in status : SterilityStatus;
            out verified : Boolean;
        }
        then action primeFluidPath {
            in fluid : MedicalFluid;
            out primed : Boolean;
        }
        then action checkConnections {
            out secure : Boolean;
        }
        then assign systemReady := checkConnections.secure;
        then done;
    }
    
    action def InsertCannula {
        in cannula : Cannula;
        in targetTissue : BiologicalTissue;
        in targetDepth : LengthValue;
        out insertionSuccess : Boolean;
        
        first start;
        then action locateInsertionSite {
            in tissue : BiologicalTissue;
            out siteIdentified : Boolean;
        }
        then action penetrateTissue {
            in depth : LengthValue;
            out penetrationComplete : Boolean;
        }
        then action verifyPlacement {
            out placementCorrect : Boolean;
        }
        then action secureDevice {
            out secured : Boolean;
        }
        then assign insertionSuccess := secureDevice.secured;
        then done;
    }
    
    action def DeliverFluid {
        in targetFlowRate : FlowRateValue;
        in targetVolume : VolumeValue;
        in maxPressure : PressureValue;
        out deliveredVolume : VolumeValue;
        
        private attribute volumeDelivered : VolumeValue;
        private attribute deliveryActive : Boolean := false;
        
        first start;
        then action initiateFlow {
            in flowRate : FlowRateValue = targetFlowRate;
            out flowStarted : Boolean;
        }
        then assign deliveryActive := true;
        then merge continueDelivery;
        then action monitorDelivery {
            in currentVolume : VolumeValue = volumeDelivered;
            in targetVol : VolumeValue = targetVolume;
            in pressure : PressureValue;
            out volumeRemaining : VolumeValue;
            out pressureSafe : Boolean;
        }
        then decide;
            if monitorDelivery.volumeRemaining > 0.0 and monitorDelivery.pressureSafe then deliverIncrement;
            if monitorDelivery.volumeRemaining <= 0.0 or not monitorDelivery.pressureSafe then stopDelivery;
        action deliverIncrement {
            in flowRate : FlowRateValue = targetFlowRate;
            out incrementVolume : VolumeValue;
        }
        then assign volumeDelivered := volumeDelivered + deliverIncrement.incrementVolume;
        then continueDelivery;
        action stopDelivery {
            out flowStopped : Boolean;
        }
        then assign deliveryActive := false;
        then assign deliveredVolume := volumeDelivered;
        then done;
    }
    
    action def RemoveCannula {
        in cannula : Cannula;
        out removalComplete : Boolean;
        
        first start;
        then action stopFlow {
            out flowStopped : Boolean;
        }
        then action withdrawDevice {
            out withdrawn : Boolean;
        }
        then action applyCompression {
            out compressionApplied : Boolean;
        }
        then action disposeDevice {
            out disposed : Boolean;
        }
        then assign removalComplete := disposeDevice.disposed;
        then done;
    }
    
    attribute def PrepareEvent;
    attribute def InsertEvent;
    attribute def StartDeliveryEvent;
    attribute def StopDeliveryEvent;
    attribute def AlarmEvent;
    attribute def ResolveEvent;
    attribute def RemoveEvent;
    
    state def CannulaSystemStates {
        entry; then idle;
        
        state idle {
            entry assign sterility := "Sterile";
        }
        accept PrepareEvent then prepared;
        
        state prepared;
        accept InsertEvent then inserted;
        
        state inserted;
        accept StartDeliveryEvent then delivering;
        
        state delivering;
        accept StopDeliveryEvent then inserted;
        accept AlarmEvent then alarm;
        
        state alarm;
        accept ResolveEvent then inserted;
        accept RemoveEvent then removing;
        
        state removing;
        then removed;
        
        state removed;
        then done;
    }
    
    action def PerformFluidDeliveryProcedure {
        in deliveryFluid : MedicalFluid;
        in deliveryVolume : VolumeValue;
        in deliveryRate : FlowRateValue;
        in targetDepth : LengthValue;
        out procedureComplete : Boolean;
        
        first start;
        then action prepare : PrepareSystem {
            out systemReady;
        }
        then action insert : InsertCannula {
            in targetDepth = PerformFluidDeliveryProcedure::targetDepth;
            out insertionSuccess;
        }
        then action deliver : DeliverFluid {
            in targetFlowRate = deliveryRate;
            in targetVolume = deliveryVolume;
            out deliveredVolume;
        }
        then action remove : RemoveCannula {
            out removalComplete;
        }
        then assign procedureComplete := remove.removalComplete;
        then done;
    }
    
    requirement def SystemFunctionalRequirements {
        doc /* The cannula delivery system shall enable controlled delivery of medical fluids into patient tissue. */
        
        requirement fluidDeliveryRequirement {
            doc /* The system shall deliver medical fluid at a specified flow rate to a target tissue depth. */
            
            require constraint flowRateAccuracy {
                doc /* Flow rate shall be maintained within +/- 5% of target rate during delivery. */
            }
            
            require constraint depthPrecision {
                doc /* Insertion depth shall be accurate to within +/- 2mm of target depth. */
            }
        }
        
        requirement safetyRequirement {
            doc /* The system shall maintain patient safety throughout the delivery procedure. */
            
            require constraint pressureLimit {
                doc /* Delivery pressure shall not exceed 400 kPa to prevent tissue damage. */
            }
            
            require constraint sterilityMaintenance {
                doc /* The system shall maintain sterility of the fluid path from reservoir to patient. */
            }
        }
        
        requirement monitoringRequirement {
            doc /* The system shall continuously monitor delivery parameters and alert on anomalies. */
        }
    }
    
    requirement def SystemPerformanceRequirements {
        doc /* The cannula delivery system shall meet specified performance criteria. */
        
        requirement flowRateCapability {
            doc /* The system shall support flow rates from 0.5 to 200 mL/min. */
        }
        
        requirement volumeAccuracy {
            doc /* Total delivered volume shall be accurate to within +/- 2% of target volume. */
        }
        
        requirement insertionForceLimit {
            doc /* Cannula insertion force shall not exceed 8 N for patient comfort. */
        }
    }
    
    part cannulaDeliverySystem {
        doc /* A medical system that delivers controlled volumes of fluid into patient tissue using a cannula. */
        
        part reservoir : FluidReservoir {
            attribute :>> capacity = 500.0[SI::mL];
            attribute :>> currentVolume = 500.0[SI::mL];
        }
        
        part controller : FlowController {
            attribute :>> targetFlowRate = 50.0[SI::mL/SI::min];
            attribute :>> maxPressure = 350000.0[SI::Pa];
        }
        
        part sensor : PressureSensor {
            attribute :>> alarmThreshold = 400000.0[SI::Pa];
        }
        
        part cannula : Cannula {
            attribute :>> gaugeSize = 20.0;
            attribute :>> sterility = "Sterile";
            
            part :>> shaft : CannulaShaft {
                attribute :>> length = 32.0[SI::mm];
                attribute :>> outerDiameter = 0.9[SI::mm];
                attribute :>> innerDiameter = 0.6[SI::mm];
                attribute :>> material = "Medical Grade Stainless Steel";
            }
            
            part :>> tip : CannulaTip {
                attribute :>> tipAngle = 15.0;
                attribute :>> sharpness = 0.92;
            }
            
            part :>> hub : CannulaHub {
                attribute :>> hubType = "Luer Lock";
                attribute :>> lockingMechanism = "Threaded";
            }
        }
        
        part patient : Patient {
            attribute :>> patientID = "PT-12345";
        }
        
        connection reservoirToController connect reservoir.fluidOutput to controller.fluidInput;
        connection controllerToSensor connect controller.fluidOutput to sensor.monitoringPort;
        connection sensorToCannula connect sensor.monitoringPort to cannula.fluidIn;
        connection cannulaToPatient connect cannula.tissueContact to patient.deliveryPoint;
        
        perform action deliveryProcedure : PerformFluidDeliveryProcedure;
    }
    
    requirement systemRequirements : SystemFunctionalRequirements {
        subject cannulaDeliverySystem;
        
        assume constraint fluidAvailable {
            doc /* Medical fluid is prepared and loaded in the reservoir. */
        }
        
        assume constraint patientPositioned {
            doc /* Patient is properly positioned and insertion site is accessible. */
        }
        
        require fluidDeliveryRequirement;
        require safetyRequirement;
        require monitoringRequirement;
    }
    
    satisfy systemRequirements.fluidDeliveryRequirement by cannulaDeliverySystem.deliveryProcedure;
    satisfy systemRequirements.safetyRequirement by cannulaDeliverySystem.sensor;
}
