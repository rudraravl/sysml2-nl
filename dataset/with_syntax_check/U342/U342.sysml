package OtoscopeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MagnificationFactor :> Real;
    attribute def IlluminationIntensity :> Real;
    attribute def ImageClarity :> Real;
    
    item def ElectricalPower {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    item def LightBeam {
        attribute intensity : LuminousIntensityValue;
        attribute wavelength : LengthValue;
    }
    
    item def OpticalImage {
        attribute magnification : MagnificationFactor;
        attribute clarity : ImageClarity;
        attribute fieldOfView : Real;
    }
    
    port def PowerInputPort {
        in item electricalPower : ElectricalPower;
    }
    
    port def LightOutputPort {
        out item lightBeam : LightBeam;
    }
    
    port def ImageOutputPort {
        out item opticalImage : OpticalImage;
    }
    
    part def BatteryPack {
        port powerOutput : PowerInputPort;
        attribute batteryVoltage : ElectricPotentialValue;
        attribute remainingCharge : Real;
        attribute totalCapacity : Real;
        
        action deliverPower {
            out power : ElectricalPower;
        }
    }
    
    part def IlluminationSource {
        port powerInput : PowerInputPort;
        port lightOutput : LightOutputPort;
        attribute operatingVoltage : ElectricPotentialValue;
        attribute lightIntensity : LuminousIntensityValue;
        attribute bulbType : String;
        
        action generateIllumination {
            in electricalInput : ElectricalPower;
            out lightOutput : LightBeam;
        }
    }
    
    part def SpeculumTip {
        port lightInput : LightOutputPort;
        attribute tipDiameter : LengthValue;
        attribute insertionLength : LengthValue;
        attribute material : String;
        
        action channelLight {
            in incomingLight : LightBeam;
            out directedLight : LightBeam;
        }
    }
    
    part def OpticalSystem {
        attribute lensConfiguration : String;
        attribute magnificationLevel : MagnificationFactor;
        attribute opticalQuality : ImageClarity;
        
        action formImage {
            in reflectedLight : LightBeam;
            out visualImage : OpticalImage;
        }
    }
    
    part def ViewingEyepiece {
        port imageOutput : ImageOutputPort;
        attribute eyeReliefDistance : LengthValue;
        attribute dioptrAdjustment : Real;
        
        action presentView {
            in imageData : OpticalImage;
            out observableImage : OpticalImage;
        }
    }
    
    part def HandleAssembly {
        attribute handleLength : LengthValue;
        attribute gripDiameter : LengthValue;
        attribute ergonomicDesign : Boolean;
    }
    
    part def HeadAssembly {
        attribute headDiameter : LengthValue;
        attribute rotationAngle : Real;
    }
    
    action def ActivateIllumination {
        in powerLevel : Real;
        out illuminationActive : Boolean;
    }
    
    action def FocusOpticalPath {
        in targetDistance : LengthValue;
        out focusAchieved : Boolean;
    }
    
    action def ConductExamination {
        in earCanalReflection : LightBeam;
        out diagnosticView : OpticalImage;
        
        first start;
        then action receiveReflection {
            in reflectedBeam = earCanalReflection;
            out capturedLight : LightBeam;
        }
        then action processOptically {
            in lightInput = receiveReflection.capturedLight;
            out processedImage : OpticalImage;
        }
        then assign diagnosticView := processOptically.processedImage;
        then done;
    }
    
    state def OtoscopeOperationalStates {
        in attribute batteryLevel : Real;
        in event powerButtonPressed;
        in event illuminationActivated;
        in event illuminationDeactivated;
        
        entry; then powerOff;
        
        state powerOff {
            doc /* Device is not energized and illumination is inactive. */
        }
        
        transition powerOff_to_standby
            first powerOff
            accept powerButtonPressed
            if batteryLevel > 15.0
            then standby;
        
        state standby {
            doc /* Device is energized but illumination is not yet active. */
        }
        
        transition standby_to_examining
            first standby
            accept illuminationActivated
            then examining;
        
        state examining {
            doc /* Device is actively illuminating and providing visualization. */
            
            state illuminating {
                doc /* Light source is emitting illumination through speculum. */
            }
            
            state imaging {
                doc /* Optical system is forming magnified image for viewing. */
            }
        }
        
        transition examining_to_standby
            first examining
            accept illuminationDeactivated
            then standby;
        
        transition standby_to_powerOff
            first standby
            accept powerButtonPressed
            then powerOff;
        
        state lowBatteryWarning;
        
        transition to_lowBattery
            first examining
            if batteryLevel <= 15.0
            then lowBatteryWarning;
        
        transition lowBattery_to_powerOff
            first lowBatteryWarning
            if batteryLevel <= 5.0
            then powerOff;
    }
    
    part def Otoscope;
    
    part otoscopeDevice : Otoscope {
        attribute deviceIdentifier : String;
        attribute manufacturerModel : String;
        attribute calibrationDate : String;
        
        part battery : BatteryPack {
            :>> batteryVoltage = 3.0 [V];
            :>> totalCapacity = 100.0;
            :>> remainingCharge = 85.0;
        }
        
        part illuminationSource : IlluminationSource {
            :>> operatingVoltage = 2.8 [V];
            :>> lightIntensity = 25.0 [cd];
            :>> bulbType = "LED";
        }
        
        part speculum : SpeculumTip {
            :>> tipDiameter = 4.0 [mm];
            :>> insertionLength = 12.0 [mm];
            :>> material = "Medical Grade Plastic";
        }
        
        part opticalSystem : OpticalSystem {
            :>> lensConfiguration = "Achromatic Doublet";
            :>> magnificationLevel = 3.5;
        }
        
        part eyepiece : ViewingEyepiece {
            :>> eyeReliefDistance = 15.0 [mm];
            :>> dioptrAdjustment = 0.0;
        }
        
        part handle : HandleAssembly {
            :>> handleLength = 120.0 [mm];
            :>> gripDiameter = 25.0 [mm];
            :>> ergonomicDesign = true;
        }
        
        part head : HeadAssembly {
            :>> headDiameter = 35.0 [mm];
            :>> rotationAngle = 0.0;
        }
        
        connection powerConnection connect battery.powerOutput to illuminationSource.powerInput;
        connection lightPathConnection connect illuminationSource.lightOutput to speculum.lightInput;
        
        action otoscopeOperation {
            first start;
            
            then action supplyPower : BatteryPack::deliverPower {
                out power;
            }
            
            then action illuminate : IlluminationSource::generateIllumination {
                in electricalInput = supplyPower.power;
                out lightOutput;
            }
            
            then action directLight : SpeculumTip::channelLight {
                in incomingLight = illuminate.lightOutput;
                out directedLight;
            }
            
            then merge examinationCycle;
            
            then action captureReflectedLight {
                in illuminatedTarget = directLight.directedLight;
                out reflectedBeam : LightBeam;
            }
            
            then action formDiagnosticImage : OpticalSystem::formImage {
                in reflectedLight = captureReflectedLight.reflectedBeam;
                out visualImage;
            }
            
            then action deliverView : ViewingEyepiece::presentView {
                in imageData = formDiagnosticImage.visualImage;
                out observableImage;
            }
            
            then decide;
                if continueDiagnostic then examinationCycle;
                if examinationComplete then conclude;
            
            action conclude {
                doc /* Examination session is concluded. */
            }
            then done;
            
            attribute continueDiagnostic : Boolean;
            attribute examinationComplete : Boolean;
        }
        
        state deviceState : OtoscopeOperationalStates {
            in attribute :>> batteryLevel = battery.remainingCharge;
        }
    }
    
    part def MedicalPractitioner;
    
    part def PatientSubject {
        part externalEar {
            attribute earCanalDepth : LengthValue;
            attribute tympanicMembraneCondition : String;
        }
    }
    
    requirement def DiagnosticVisualizationCapability {
        doc /* 
        The otoscope shall provide clear, magnified visualization of the ear canal 
        and tympanic membrane for medical diagnostic purposes.
        */
        
        require illuminationRequirement;
        require magnificationRequirement;
        require opticalClarityRequirement;
        require safetyRequirement;
    }
    
    requirement <'OTO-REQ-001'> illuminationRequirement {
        doc /* 
        The illumination source shall provide sufficient light intensity 
        to clearly visualize anatomical structures within the ear canal.
        */
        
        subject device : Otoscope = otoscopeDevice;
        
        assume constraint {
            device.battery.remainingCharge > 15.0
        }
        
        require constraint {
            device.illuminationSource.lightIntensity >= 20.0 [cd]
        }
    }
    
    requirement <'OTO-REQ-002'> magnificationRequirement {
        doc /* 
        The optical system shall provide magnification between 2.5x and 4.0x 
        to enable detailed examination of ear structures.
        */
        
        subject device : Otoscope = otoscopeDevice;
        
        require constraint {
            device.opticalSystem.magnificationLevel >= 2.5 and
            device.opticalSystem.magnificationLevel <= 4.0
        }
    }
    
    requirement <'OTO-REQ-003'> opticalClarityRequirement {
        doc /* 
        The optical system shall deliver distortion-free, high-clarity images 
        across the entire field of view.
        */
        
        subject device : Otoscope = otoscopeDevice;
    }
    
    requirement <'OTO-REQ-004'> safetyRequirement {
        doc /* 
        The speculum tip shall be designed with appropriate dimensions 
        to prevent injury during insertion into the ear canal.
        */
        
        subject device : Otoscope = otoscopeDevice;
        
        require constraint {
            device.speculum.insertionLength <= 15.0 [mm] and
            device.speculum.tipDiameter >= 2.5 [mm] and
            device.speculum.tipDiameter <= 5.0 [mm]
        }
    }
    
    requirement <'OTO-REQ-005'> batteryEnduranceRequirement {
        doc /* 
        The battery pack shall provide continuous operation for at least 
        45 minutes under normal examination conditions.
        */
        
        subject device : Otoscope = otoscopeDevice;
        
        require constraint {
            device.battery.totalCapacity >= 45.0
        }
    }
    
    requirement <'OTO-REQ-006'> ergonomicRequirement {
        doc /* 
        The handle assembly shall be ergonomically designed to enable 
        comfortable manipulation during extended examination sessions.
        */
        
        subject device : Otoscope = otoscopeDevice;
        
        require constraint {
            device.handle.ergonomicDesign == true
        }
    }
    
    requirement primaryDiagnosticFunction : DiagnosticVisualizationCapability {
        doc /* 
        The otoscope system enables medical examination of the external auditory canal 
        and tympanic membrane by providing battery-powered illumination and optical 
        magnification, allowing healthcare practitioners to visually assess ear health 
        and diagnose conditions such as infections, perforations, or obstructions.
        */
    }
    
    occurrence def ClinicalEarExamination {
        ref part practitioner : MedicalPractitioner;
        ref part diagnosticDevice : Otoscope :> otoscopeDevice;
        ref part patient : PatientSubject;
        
        then action prepareEquipment {
            doc /* Practitioner selects appropriate speculum size and attaches to otoscope head. */
        }
        
        then action activateDevice {
            doc /* Practitioner activates otoscope power and illumination system. */
        }
        
        then action positionPatient {
            doc /* Practitioner positions patient and stabilizes head for examination. */
        }
        
        then action insertSpeculum {
            doc /* Practitioner gently inserts speculum into external ear canal. */
        }
        
        then action visualizeStructures {
            doc /* Practitioner observes ear canal and tympanic membrane through eyepiece. */
        }
        
        then action assessFindings {
            doc /* Practitioner evaluates anatomical structures for abnormalities or pathology. */
        }
        
        then action withdrawSpeculum {
            doc /* Practitioner carefully removes speculum from ear canal. */
        }
        
        then action deactivateDevice {
            doc /* Practitioner deactivates otoscope illumination and power. */
        }
        
        then action documentFindings {
            doc /* Practitioner records examination findings in patient medical record. */
        }
    }
}
