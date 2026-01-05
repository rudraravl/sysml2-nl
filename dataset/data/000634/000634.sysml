package 'Hybrid Operating Room System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SurgicalProcedureType;
    attribute def ImagingModality;
    attribute def SterilityStatus;
    attribute def AlarmLevel;
    
    item def Patient {
        attribute heartRate : FrequencyValue;
        attribute bloodPressure : PressureValue;
        attribute oxygenSaturation : Real;
        attribute bodyTemperature : ThermodynamicTemperatureValue;
    }
    
    item def MedicalImage {
        attribute modality : ImagingModality;
        attribute resolution : Real;
        attribute timestamp : TimeValue;
        attribute anatomicalRegion : String;
    }
    
    item def SurgicalInstrument {
        attribute instrumentID : String;
        attribute sterilityStatus : SterilityStatus;
        attribute position : LengthValue[3];
    }
    
    port def PowerPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    port def DataPort {
        in commands : String[*];
        out data : String[*];
    }
    
    port def ImagePort {
        out images : MedicalImage[*];
    }
    
    port def VitalsPort {
        out vitals : Patient;
    }
    
    part def ImagingSystem {
        port powerIn : PowerPort;
        port controlInterface : DataPort;
        port imageOutput : ImagePort;
        
        attribute currentModality : ImagingModality;
        attribute radiationDose : AbsorbedDoseValue;
        attribute cArmAngle : PlaneAngleValue;
        
        part xRaySource {
            attribute outputPower : PowerValue;
            attribute exposureTime : TimeValue;
        }
        
        part detector {
            attribute sensitivity : Real;
            attribute pixelResolution : Real;
        }
        
        part imageProcessor {
            attribute processingRate : FrequencyValue;
            attribute enhancementLevel : Real;
        }
        
        action def AcquireImage {
            in targetRegion : String;
            in modality : ImagingModality;
            out capturedImage : MedicalImage;
            out doseDelivered : AbsorbedDoseValue;
        }
        
        state def ImagingStates {
            entry; then Standby;
            
            state Standby;
            state Positioning;
            state Acquiring;
            state Processing;
            state Transmitting;
            
            transition first Standby then Positioning;
            transition first Positioning then Acquiring;
            transition first Acquiring then Processing;
            transition first Processing then Transmitting;
            transition first Transmitting then Standby;
        }
    }
    
    part def SurgicalTable {
        port powerIn : PowerPort;
        port controlInterface : DataPort;
        
        attribute height : LengthValue;
        attribute tiltAngle : PlaneAngleValue;
        attribute lateralShift : LengthValue;
        attribute longitudinalShift : LengthValue;
        
        action def PositionTable {
            in targetHeight : LengthValue;
            in targetTilt : PlaneAngleValue;
            out positioned : Boolean;
        }
    }
    
    part def PatientMonitoringSystem {
        port powerIn : PowerPort;
        port vitalsOutput : VitalsPort;
        port alarmInterface : DataPort;
        
        attribute monitoringInterval : TimeValue;
        
        part ecgMonitor {
            attribute heartRate : FrequencyValue;
            attribute rhythm : String;
        }
        
        part pulseOximeter {
            attribute spo2 : Real;
            attribute perfusionIndex : Real;
        }
        
        part bloodPressureMonitor {
            attribute systolic : PressureValue;
            attribute diastolic : PressureValue;
            attribute mean : PressureValue;
        }
        
        part temperatureSensor {
            attribute coreTemp : ThermodynamicTemperatureValue;
        }
        
        action def MonitorVitals {
            out currentVitals : Patient;
            out alarmStatus : AlarmLevel;
        }
    }
    
    part def AnesthesiaDeliverySystem {
        port powerIn : PowerPort;
        port controlInterface : DataPort;
        port gasSupply;
        
        attribute gasFlowRate : VolumeFlowRateValue;
        attribute anestheticConcentration : Real;
        attribute ventilationRate : FrequencyValue;
        attribute tidalVolume : VolumeValue;
        
        action def DeliverAnesthesia {
            in targetConcentration : Real;
            in targetFlowRate : VolumeFlowRateValue;
            out actualConcentration : Real;
        }
        
        action def ControlVentilation {
            in targetRate : FrequencyValue;
            in targetVolume : VolumeValue;
            out actualRate : FrequencyValue;
        }
    }
    
    part def SurgicalLightingSystem {
        port powerIn : PowerPort;
        port controlInterface : DataPort;
        
        attribute intensity : LuminousIntensityValue;
        attribute colorTemperature : ThermodynamicTemperatureValue;
        attribute focusArea : AreaValue;
        attribute shadowReduction : Real;
        
        action def AdjustLighting {
            in targetIntensity : LuminousIntensityValue;
            in focusPoint : LengthValue[3];
            out actualIntensity : LuminousIntensityValue;
        }
    }
    
    part def EnvironmentalControlSystem {
        port powerIn : PowerPort;
        
        attribute airFlowRate : VolumeFlowRateValue;
        attribute roomTemperature : ThermodynamicTemperatureValue;
        attribute humidity : Real;
        attribute filterEfficiency : Real;
        attribute pressureDifferential : PressureValue;
        
        action def MaintainEnvironment {
            in targetTemperature : ThermodynamicTemperatureValue;
            in targetHumidity : Real;
            out actualTemperature : ThermodynamicTemperatureValue;
            out sterilityLevel : SterilityStatus;
        }
    }
    
    part def DisplaySystem {
        port powerIn : PowerPort;
        port imageInput : ImagePort;
        port dataInput : DataPort;
        
        attribute screenSize : LengthValue;
        attribute resolution : Real;
        attribute refreshRate : FrequencyValue;
        
        part primaryDisplay {
            attribute displayType : String;
        }
        
        part secondaryDisplay {
            attribute displayType : String;
        }
        
        action def DisplayImages {
            in images : MedicalImage[*];
            in vitals : Patient;
        }
    }
    
    part def NavigationSystem {
        port powerIn : PowerPort;
        port controlInterface : DataPort;
        
        attribute trackingAccuracy : LengthValue;
        attribute updateRate : FrequencyValue;
        
        action def TrackInstruments {
            in instruments : SurgicalInstrument[*];
            out positions : LengthValue[3][*];
            out accuracy : LengthValue;
        }
    }
    
    action def PerformImageGuidedProcedure {
        in patient : Patient;
        in procedureType : SurgicalProcedureType;
        in maxRadiationDose : AbsorbedDoseValue;
        out procedureComplete : Boolean;
        out totalDose : AbsorbedDoseValue;
        
        private attribute accumulatedDose : AbsorbedDoseValue := 0.0;
        private attribute vitalStatus : Patient;
        
        first start;
        
        then action preparePatient : SurgicalTable::PositionTable {
            in targetHeight;
            in targetTilt;
            out positioned;
        }
        
        then action initiateAnesthesia : AnesthesiaDeliverySystem::DeliverAnesthesia {
            in targetConcentration;
            in targetFlowRate;
            out actualConcentration;
        }
        
        then action adjustLighting : SurgicalLightingSystem::AdjustLighting {
            in targetIntensity;
            in focusPoint;
            out actualIntensity;
        }
        
        then merge procedureLoop;
        
        action monitorPatient : PatientMonitoringSystem::MonitorVitals {
            out currentVitals;
            out alarmStatus;
        }
        
        then assign vitalStatus := monitorPatient.currentVitals;
        
        then action acquireImage : ImagingSystem::AcquireImage {
            in targetRegion;
            in modality;
            out capturedImage;
            out doseDelivered;
        }
        
        then assign accumulatedDose := accumulatedDose + acquireImage.doseDelivered;
        
        then action displayImage : DisplaySystem::DisplayImages {
            in images := (acquireImage.capturedImage);
            in vitals := vitalStatus;
        }
        
        then action trackInstruments : NavigationSystem::TrackInstruments {
            in instruments;
            out positions;
            out accuracy;
        }
        
        then decide;
            if vitalStatus.oxygenSaturation < 0.90 then emergencyResponse;
            if accumulatedDose >= maxRadiationDose then completeProcedure;
            if vitalStatus.oxygenSaturation >= 0.95 then procedureLoop;
        
        action emergencyResponse {
            then action stabilize : AnesthesiaDeliverySystem::ControlVentilation {
                in targetRate;
                in targetVolume;
                out actualRate;
            }
            then procedureLoop;
        }
        
        action completeProcedure {
            then assign procedureComplete := true;
            then assign totalDose := accumulatedDose;
        }
        
        then done;
    }
    
    part def HybridOperatingRoom;
    
    part hybridOR : HybridOperatingRoom {
        doc /* 
            Hybrid Operating Room integrating advanced medical imaging with surgical capabilities
            to enable real-time image-guided minimally invasive procedures.
        */
        
        attribute roomTemperature : ThermodynamicTemperatureValue;
        attribute roomPressure : PressureValue;
        
        perform action imageGuidedProcedure[*] ordered references PerformImageGuidedProcedure;
        
        part imaging : ImagingSystem {
            perform imageGuidedProcedure.acquireImage;
        }
        
        part table : SurgicalTable {
            perform imageGuidedProcedure.preparePatient;
        }
        
        part monitoring : PatientMonitoringSystem {
            perform imageGuidedProcedure.monitorPatient;
        }
        
        part anesthesia : AnesthesiaDeliverySystem {
            perform imageGuidedProcedure.initiateAnesthesia;
        }
        
        part lighting : SurgicalLightingSystem {
            perform imageGuidedProcedure.adjustLighting;
        }
        
        part environment : EnvironmentalControlSystem;
        
        part displays : DisplaySystem {
            perform imageGuidedProcedure.displayImage;
        }
        
        part navigation : NavigationSystem {
            perform imageGuidedProcedure.trackInstruments;
        }
        
        connection imagingToDisplay connect imaging.imageOutput to displays.imageInput;
        connection monitoringToDisplay connect monitoring.vitalsOutput to displays.dataInput;
        connection imagingControl connect imaging.controlInterface to displays.dataInput;
    }
    
    requirement def FunctionalRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    
    requirement <'HOR-REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* 
            The Hybrid Operating Room shall integrate real-time medical imaging capabilities
            with a sterile surgical environment to enable image-guided minimally invasive
            procedures, combining diagnostic imaging and therapeutic intervention in a single
            controlled space.
        */
        
        subject hybridORCapability : HybridOperatingRoom;
    }
    
    requirement <'HOR-REQ-002'> imageQuality : PerformanceRequirement {
        doc /* 
            The imaging system shall provide high-resolution images with minimum 1024x1024
            pixel resolution and detector sensitivity greater than 95% for surgical guidance.
        */
        
        subject imagingCapability : ImagingSystem;
        
        require constraint {
            imagingCapability.detector.pixelResolution >= 1024.0 and
            imagingCapability.detector.sensitivity >= 0.95
        }
    }
    
    requirement <'HOR-REQ-003'> radiationSafety : SafetyRequirement {
        doc /* 
            The system shall limit cumulative radiation dose per procedure to ALARA principles
            and shall not exceed prescribed maximum dose limits.
        */
        
        subject imagingCapability : ImagingSystem;
        
        require constraint {
            imagingCapability.radiationDose <= 5.0
        }
    }
    
    requirement <'HOR-REQ-004'> patientMonitoring : SafetyRequirement {
        doc /* 
            Patient vital signs shall be continuously monitored with update intervals
            not exceeding 1 second, with immediate alarm generation for critical values.
        */
        
        subject monitoringCapability : PatientMonitoringSystem;
        
        require constraint {
            monitoringCapability.monitoringInterval <= 1.0
        }
    }
    
    requirement <'HOR-REQ-005'> sterileEnvironment : SafetyRequirement {
        doc /* 
            The operating room shall maintain ISO Class 5 cleanroom conditions with
            HEPA filtration efficiency exceeding 99.99% and positive pressure differential.
        */
        
        subject environmentCapability : EnvironmentalControlSystem;
        
        require constraint {
            environmentCapability.filterEfficiency >= 0.9999 and
            environmentCapability.pressureDifferential >= 2.5
        }
    }
    
    requirement <'HOR-REQ-006'> navigationAccuracy : PerformanceRequirement {
        doc /* 
            The surgical navigation system shall provide instrument tracking accuracy
            within 1.0 mm for image-guided procedures.
        */
        
        subject navigationCapability : NavigationSystem;
        
        require constraint {
            navigationCapability.trackingAccuracy <= 1.0
        }
    }
    
    requirement <'HOR-REQ-007'> systemIntegration : FunctionalRequirement {
        doc /* 
            All subsystems shall be integrated to provide coordinated real-time operation
            during image-guided procedures with synchronized data display and control.
        */
        
        subject systemCapability : HybridOperatingRoom;
        
        require imageQuality;
        require radiationSafety;
        require patientMonitoring;
        require sterileEnvironment;
        require navigationAccuracy;
    }
    
    requirement <'HOR-REQ-008'> missionRequirement : FunctionalRequirement {
        doc /* 
            The Hybrid Operating Room system shall enable minimally invasive surgical
            interventions with real-time imaging guidance while maintaining patient safety
            through continuous monitoring and sterile environmental control.
        */
        
        satisfy by hybridOR verify primaryFunction;
        require systemIntegration;
    }
}
