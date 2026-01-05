package 'Lead Shielding System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RadiationDoseRate :> ISQ::PowerValue {
        doc /* Rate of ionizing radiation dose measured in Sieverts per hour */
    }
    
    attribute def ShieldThickness :> ISQ::LengthValue {
        doc /* Thickness of lead shielding material in meters */
    }
    
    attribute def AttenuationFactor :> Real {
        doc /* Linear attenuation coefficient for lead material */
    }
    
    attribute def ShieldingEffectiveness :> Real {
        doc /* Fraction of incident radiation blocked by shield */
    }
    
    item def RadiationSource {
        doc /* Radioactive source emitting ionizing radiation */
        attribute sourceIntensity : RadiationDoseRate;
        attribute sourceEnergy : ISQ::EnergyValue;
        attribute sourceType : String;
    }
    
    item def ProtectedZone {
        doc /* Area requiring radiation protection for personnel or equipment */
        attribute maxPermissibleDose : RadiationDoseRate;
        attribute exposureDuration : ISQ::TimeValue;
        attribute zoneVolume : ISQ::VolumeValue;
    }
    
    part def LeadMaterial {
        doc /* Lead shielding material with radiation attenuation properties */
        attribute materialDensity : ISQ::DensityValue;
        attribute shieldThickness : ShieldThickness;
        attribute materialPurity : Real;
        attribute linearAttenuationCoeff : AttenuationFactor;
    }
    
    part def DosimeterSensor {
        doc /* Radiation detection sensor for dose rate measurement */
        attribute measurementRange : RadiationDoseRate;
        attribute sensorAccuracy : Real;
        attribute calibrationDate : String;
        port sensorInput;
        port dataOutput;
    }
    
    part def AlarmController {
        doc /* Controller for radiation alarm and safety interlock */
        attribute alarmThreshold : RadiationDoseRate;
        attribute alarmActive : Boolean;
        attribute interlockEngaged : Boolean;
        port alarmInput;
        port alarmSignal;
        port interlockControl;
    }
    
    port def RadiationPort {
        in incidentRadiation : RadiationDoseRate;
        out transmittedRadiation : RadiationDoseRate;
    }
    
    port def MonitoringPort {
        in measuredDose : RadiationDoseRate;
        out statusSignal : Boolean;
    }
    
    port def ControlPort {
        in controlCommand : Boolean;
        out systemStatus : String;
    }
    
    action def MeasureDoseRate {
        in incidentDose : RadiationDoseRate;
        in backgroundDose : RadiationDoseRate;
        out netDose : RadiationDoseRate;
        out exceedsThreshold : Boolean;
    }
    
    action def ComputeShieldingAttenuation {
        in incidentDose : RadiationDoseRate;
        in thickness : ShieldThickness;
        in attenuationCoeff : AttenuationFactor;
        out transmittedDose : RadiationDoseRate;
        out attenuationEfficiency : ShieldingEffectiveness;
    }
    
    action def ActivateAlarm {
        in currentDose : RadiationDoseRate;
        in thresholdDose : RadiationDoseRate;
        out alarmTriggered : Boolean;
        out interlockActivated : Boolean;
    }
    
    action def ProvideRadiationShielding {
        doc /* Primary system action: attenuate ionizing radiation to safe levels */
        in radiationSource : RadiationSource;
        in protectedZone : ProtectedZone;
        in shieldMaterial : LeadMaterial;
        out finalDoseRate : RadiationDoseRate;
        out shieldingAdequate : Boolean;
        
        first start;
        then merge continuousShielding;
        
        then action measureIncident : MeasureDoseRate {
            in incidentDose = radiationSource.sourceIntensity;
            in backgroundDose = 0.0;
            out netDose;
            out exceedsThreshold;
        }
        
        then action attenuateRadiation : ComputeShieldingAttenuation {
            in incidentDose = measureIncident.netDose;
            in thickness = shieldMaterial.shieldThickness;
            in attenuationCoeff = shieldMaterial.linearAttenuationCoeff;
            out transmittedDose;
            out attenuationEfficiency;
        }
        
        then decide;
            if attenuateRadiation.transmittedDose <= protectedZone.maxPermissibleDose then safeOperation;
            if attenuateRadiation.transmittedDose > protectedZone.maxPermissibleDose then unsafeCondition;
        
        action safeOperation {
            then assign finalDoseRate := attenuateRadiation.transmittedDose;
            then assign shieldingAdequate := true;
        }
        then continuousShielding;
        
        action unsafeCondition : ActivateAlarm {
            in currentDose = attenuateRadiation.transmittedDose;
            in thresholdDose = protectedZone.maxPermissibleDose;
            out alarmTriggered;
            out interlockActivated;
            then assign finalDoseRate := attenuateRadiation.transmittedDose;
            then assign shieldingAdequate := false;
        }
        then continuousShielding;
    }
    
    requirement def RadiationShieldingRequirement {
        doc /* Requirements for effective radiation protection system */
        subject shieldSystem : LeadShieldingSystem;
        
        require constraint doseLimitCompliance {
            doc /* Transmitted dose must remain below regulatory limits */
            shieldSystem.measuredTransmittedDose <= shieldSystem.regulatoryDoseLimit
        }
        
        require constraint adequateThickness {
            doc /* Shield thickness must meet minimum design specification */
            shieldSystem.leadShield.shieldThickness >= shieldSystem.minimumRequiredThickness
        }
        
        require constraint continuousMonitoring {
            doc /* System must provide continuous radiation monitoring */
            shieldSystem.dosimeter.sensorAccuracy >= 0.90
        }
        
        require constraint alarmFunctionality {
            doc /* Alarm must activate when dose exceeds threshold */
            shieldSystem.alarmController.alarmActive == true or 
            shieldSystem.measuredTransmittedDose <= shieldSystem.regulatoryDoseLimit
        }
    }
    
    requirement <'SHIELD-REQ-001'> primaryShieldingRequirement : RadiationShieldingRequirement {
        doc /* The lead shielding system shall reduce ionizing radiation to safe exposure levels */
        
        assume constraint sourceCharacterized {
            doc /* Radiation source characteristics are known and documented */
        }
        
        assume constraint materialQuality {
            doc /* Lead material meets purity and density specifications */
        }
        
        require constraint attenuationPerformance {
            doc /* System must attenuate at least 95% of incident radiation */
        }
    }
    
    part def LeadShieldingSystem {
        doc /* 
            Complete radiation protection system using lead shielding.
            Primary function: Attenuate harmful ionizing radiation to protect personnel 
            and equipment by interposing dense lead material between radiation source 
            and protected zone, with continuous monitoring and alarm capability.
        */
        
        attribute regulatoryDoseLimit : RadiationDoseRate;
        attribute minimumRequiredThickness : ShieldThickness;
        attribute measuredTransmittedDose : RadiationDoseRate;
        attribute systemOperational : Boolean;
        
        part source : RadiationSource {
            :>> sourceIntensity = 500.0;
            :>> sourceEnergy = 1.25;
            :>> sourceType = "Cobalt-60";
        }
        
        part leadShield : LeadMaterial {
            :>> materialDensity = 11340.0;
            :>> shieldThickness = 0.075;
            :>> materialPurity = 0.995;
            :>> linearAttenuationCoeff = 0.65;
        }
        
        part protectedArea : ProtectedZone {
            :>> maxPermissibleDose = 2.5;
            :>> exposureDuration = 8.0;
            :>> zoneVolume = 100.0;
        }
        
        part dosimeter : DosimeterSensor {
            :>> measurementRange = 1000.0;
            :>> sensorAccuracy = 0.95;
            :>> calibrationDate = "2024-01-15";
            perform shieldingOperation.measureIncident;
        }
        
        part alarmController : AlarmController {
            :>> alarmThreshold = protectedArea.maxPermissibleDose;
            :>> alarmActive = false;
            :>> interlockEngaged = false;
            perform shieldingOperation.unsafeCondition;
        }
        
        port radiationInlet : RadiationPort;
        port radiationOutlet : RadiationPort;
        port monitoringInterface : MonitoringPort;
        port controlInterface : ControlPort;
        
        perform action shieldingOperation : ProvideRadiationShielding {
            in radiationSource = source;
            in protectedZone = protectedArea;
            in shieldMaterial = leadShield;
            out finalDoseRate;
            out shieldingAdequate;
        }
        
        connection sourceToShield connect source to leadShield;
        connection shieldToProtected connect leadShield to protectedArea;
        connection monitoringConnection connect dosimeter.dataOutput to alarmController.alarmInput;
        connection alarmConnection connect alarmController.alarmSignal to controlInterface;
        
        bind measuredTransmittedDose = shieldingOperation.finalDoseRate;
        bind systemOperational = shieldingOperation.shieldingAdequate;
    }
    
    part operationalShieldingSystem : LeadShieldingSystem {
        doc /* 
            Deployed lead shielding system for industrial radiography facility.
            Provides continuous radiation protection through passive lead attenuation
            combined with active dose monitoring and automated safety interlocks.
        */
        
        :>> regulatoryDoseLimit = 2.5;
        :>> minimumRequiredThickness = 0.050;
        
        satisfy primaryShieldingRequirement;
    }
}
