package 'Jet Injector System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TriggerSignal;
    attribute def InjectionComplete;
    
    item def Medication {
        doc /* Sterile liquid pharmaceutical formulation to be delivered. */
        attribute volume : VolumeValue;
        attribute viscosity : DynamicViscosityValue;
        attribute sterile : Boolean;
    }
    
    item def CompressedGas {
        doc /* High-pressure gas used to drive the injection mechanism. */
        attribute pressure : PressureValue;
        attribute volume : VolumeValue;
    }
    
    requirement def DeliverMedicationNeedleFree {
        doc /* The jet injector shall deliver a precise dose of medication through intact skin 
             without the use of a hypodermic needle by generating a high-velocity fluid jet. */
        subject jetInjectorSystem : JetInjector;
        require constraint { jetInjectorSystem.nozzle.jetVelocity >= 100.0 }
        require constraint { jetInjectorSystem.nozzle.jetPressure >= 10.0e6 }
    }
    
    requirement def DoseAccuracyRequirement {
        doc /* The delivered medication volume shall be within ±5% of the prescribed dose. */
        attribute prescribedDose : VolumeValue;
        attribute deliveredDose : VolumeValue;
        require constraint { deliveredDose >= prescribedDose * 0.95 }
        require constraint { deliveredDose <= prescribedDose * 1.05 }
    }
    
    requirement def SkinPenetrationRequirement {
        doc /* The jet shall penetrate the epidermis and deliver medication to subcutaneous tissue. */
        attribute penetrationDepth : LengthValue;
        require constraint { penetrationDepth >= 0.004 }
        require constraint { penetrationDepth <= 0.006 }
    }
    
    part def AmpouleReservoir {
        doc /* Sealed container holding the sterile medication dose. */
        attribute capacity : VolumeValue;
        port medicationOut : Medication;
        item storedMedication : Medication[1];
    }
    
    part def GasPowerSource {
        doc /* Compressed gas cartridge providing energy for injection. */
        attribute maxPressure : PressureValue;
        port gasOut : CompressedGas;
        item gasSupply : CompressedGas[1];
    }
    
    part def PistonChamber {
        doc /* Mechanical actuator that converts gas pressure into linear force on medication. */
        port gasIn : CompressedGas;
        port medicationIn : Medication;
        port medicationOut : Medication;
        attribute pistonArea : AreaValue;
        attribute stroke : LengthValue;
    }
    
    part def MicroOrificeNozzle {
        doc /* Precision orifice that forms the high-velocity medication jet. */
        attribute orificeDiameter : LengthValue;
        attribute jetVelocity : SpeedValue;
        attribute jetPressure : PressureValue;
        port medicationIn : Medication;
        port jetOut : Medication;
    }
    
    part def TriggerMechanism {
        doc /* User-activated control that initiates the injection sequence. */
        port triggerSignal : TriggerSignal;
    }
    
    part def SafetyInterlock {
        doc /* Mechanism ensuring proper device placement before allowing injection. */
        attribute skinContactDetected : Boolean;
        port enableSignal : Boolean;
    }
    
    action def ChargeSystem {
        doc /* Load medication ampoule and prime the gas pressure system. */
        out systemReady : Boolean;
    }
    
    action def DetectSkinContact {
        doc /* Verify device is properly positioned against patient skin. */
        out contactConfirmed : Boolean;
    }
    
    action def ReleaseGasPressure {
        doc /* Discharge compressed gas to drive the piston. */
        in gasPressure : PressureValue;
        out pistonForce : ForceValue;
    }
    
    action def PressurizeMedication {
        doc /* Transfer force from piston to medication, creating high pressure. */
        in pistonForce : ForceValue;
        in medicationVolume : VolumeValue;
        out fluidPressure : PressureValue;
    }
    
    action def FormJet {
        doc /* Expel pressurized medication through micro-orifice to create penetrating jet. */
        in fluidPressure : PressureValue;
        in orificeDiameter : LengthValue;
        out jetVelocity : SpeedValue;
        out deliveredMedication : Medication;
    }
    
    action def CompleteInjection {
        doc /* Finalize injection cycle and prepare for device removal. */
        out injectionComplete : InjectionComplete;
    }
    
    action def PerformNeedleFreeInjection {
        doc /* Execute complete injection sequence from trigger to delivery. */
        in trigger : TriggerSignal;
        in prescribedDose : VolumeValue;
        out deliveredDose : Medication;
        out completion : InjectionComplete;
        
        first start;
        then action charge : ChargeSystem {
            out systemReady : Boolean;
        }
        then action detectContact : DetectSkinContact {
            out contactConfirmed : Boolean;
        }
        then decide;
            if detectContact.contactConfirmed then releaseGas;
            else abort;
        action releaseGas : ReleaseGasPressure {
            in gasPressure : PressureValue;
            out pistonForce : ForceValue;
        }
        then action pressurizeMed : PressurizeMedication {
            in pistonForce = releaseGas.pistonForce;
            in medicationVolume = prescribedDose;
            out fluidPressure : PressureValue;
        }
        then action formJet : FormJet {
            in fluidPressure = pressurizeMed.fluidPressure;
            in orificeDiameter : LengthValue;
            out jetVelocity : SpeedValue;
            out deliveredMedication : Medication;
        }
        then action complete : CompleteInjection {
            out injectionComplete : InjectionComplete;
        }
        then assign deliveredDose := formJet.deliveredMedication;
        then assign completion := complete.injectionComplete;
        then done;
        action abort : CompleteInjection;
        then done;
    }
    
    part def JetInjector {
        doc /* Needle-free injection device that delivers medication through skin using 
             a high-velocity fluid jet generated by compressed gas pressure. */
        
        attribute prescribedDoseVolume : VolumeValue;
        
        part ampoule : AmpouleReservoir {
            attribute capacity = 0.0005;
        }
        
        part gasPowerSource : GasPowerSource {
            attribute maxPressure = 30.0e6;
        }
        
        part piston : PistonChamber {
            attribute pistonArea = 0.00005;
            attribute stroke = 0.01;
        }
        
        part nozzle : MicroOrificeNozzle {
            attribute orificeDiameter = 0.00015;
            attribute jetVelocity = 150.0;
            attribute jetPressure = 15.0e6;
        }
        
        part trigger : TriggerMechanism;
        
        part safetyInterlock : SafetyInterlock;
        
        port patientInterface : Medication;
        
        connect gasPowerSource.gasOut to piston.gasIn;
        connect ampoule.medicationOut to piston.medicationIn;
        connect piston.medicationOut to nozzle.medicationIn;
        connect nozzle.jetOut to patientInterface;
        
        perform action injection[*] ordered : PerformNeedleFreeInjection {
            in prescribedDose = prescribedDoseVolume;
        }
        
        satisfy deliverMedicationReq : DeliverMedicationNeedleFree by injection;
        satisfy doseAccuracyReq : DoseAccuracyRequirement by injection {
            redefines prescribedDose = prescribedDoseVolume;
            redefines deliveredDose = injection.deliveredDose.volume;
        }
        satisfy skinPenetrationReq : SkinPenetrationRequirement by nozzle;
    }
    
    part jetInjectorSystem : JetInjector {
        attribute prescribedDoseVolume = 0.0003;
    }
}
