package IontophoreticDrugDeliverySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    item def IonizedDrug;
    
    attribute def TreatmentStartSignal;
    attribute def TreatmentCompleteSignal;
    attribute def FaultSignal;
    attribute def ResetSignal;
    attribute def ElectrodesReadySignal;
    
    port def CurrentPort {
        out item current : ElectricCurrent;
    }
    
    port def DrugPort {
        out item drug : IonizedDrug;
    }
    
    port def SensorPort {
        out item measurement : ElectricalResistanceValue;
    }
    
    part def Patient {
        port activeSite : ~CurrentPort;
        port returnSite : CurrentPort;
        attribute skinImpedance : ElectricalResistanceValue;
    }
    
    part def DrugReservoir {
        attribute targetDosage : MassValue;
        attribute deliveredDosage : MassValue = 0 [mg];
        item drug : IonizedDrug;
    }
    
    part def ActiveElectrode {
        part drugReservoir : DrugReservoir;
        port electrodePort : CurrentPort;
        port drugOut : DrugPort;
    }
    
    part def ReturnElectrode {
        port electrodePort : ~CurrentPort;
    }
    
    part def PowerSupply {
        port currentOut : CurrentPort;
        attribute outputCurrent : ElectricCurrent;
    }
    
    part def CurrentRegulator {
        port currentIn : ~CurrentPort;
        port currentOut : CurrentPort;
        attribute targetCurrent : ElectricCurrent;
        attribute regulatedCurrent : ElectricCurrent;
    }
    
    part def ImpedanceSensor {
        port sensorOut : SensorPort;
        attribute measuredImpedance : ElectricalResistanceValue;
    }
    
    part def SafetyMonitor {
        port sensorIn : ~SensorPort;
        attribute maxCurrent : ElectricCurrent = 4 [mA];
        attribute minCurrent : ElectricCurrent = 2 [mA];
        attribute maxTreatmentTime : DurationValue = 3600 [s];
        attribute maxImpedance : ElectricalResistanceValue = 100000 [Ohm];
        attribute minImpedance : ElectricalResistanceValue = 1000 [Ohm];
        attribute elapsedTreatmentTime : DurationValue = 0 [s];
        attribute faultActive : Boolean = false;
    }
    
    part def TreatmentController {
        attribute targetDosage : MassValue;
        attribute deliveredDosage : MassValue = 0 [mg];
        attribute treatmentActive : Boolean = false;
    }
    
    part def IontophoresisDevice {
        part treatmentController : TreatmentController;
        part powerSupply : PowerSupply;
        part currentRegulator : CurrentRegulator;
        part activeElectrode : ActiveElectrode;
        part returnElectrode : ReturnElectrode;
        part safetyMonitor : SafetyMonitor;
        part impedanceSensor : ImpedanceSensor;
    }
    
    action def ProvidePower {
        out current : ElectricCurrent;
    }
    
    action def RegulateCurrent {
        in rawCurrent : ElectricCurrent;
        in targetCurrent : ElectricCurrent;
        out regulatedCurrent : ElectricCurrent;
    }
    
    action def DeliverDrug {
        in current : ElectricCurrent;
        inout deliveredDosage : MassValue;
    }
    
    action def MeasureImpedance {
        out impedance : ElectricalResistanceValue;
    }
    
    action def CheckSafety {
        in current : ElectricCurrent;
        in impedance : ElectricalResistanceValue;
        in elapsedTime : DurationValue;
        out fault : Boolean;
    }
    
    action def StopCurrent;
    action def TerminateTreatment;
    
    state def TreatmentStates;
    
    part device : IontophoresisDevice {
        action providePower : ProvidePower;
        action regulateCurrent : RegulateCurrent;
        action deliverDrug : DeliverDrug;
        action measureImpedance : MeasureImpedance;
        action checkSafety : CheckSafety;
        action stopCurrent : StopCurrent;
        action terminateTreatment : TerminateTreatment;
        
        flow of current : ElectricCurrent
            from powerSupply.currentOut.current
            to currentRegulator.currentIn.current;
        
        flow of current : ElectricCurrent
            from currentRegulator.currentOut.current
            to activeElectrode.electrodePort.current;
        
        connect impedanceSensor.sensorOut to safetyMonitor.sensorIn;
        
        exhibit state treatmentStates : TreatmentStates {
            entry; then idle;
            
            state idle;
            accept TreatmentStartSignal
                then preparation;
            
            state preparation;
            accept when impedanceSensor.measuredImpedance < safetyMonitor.maxImpedance
                do send new ElectrodesReadySignal() to treatmentController
                then activeDelivery;
            
            state activeDelivery {
                entry assign currentRegulator.targetCurrent := 3 [mA];
                do providePower {
                    out current = powerSupply.outputCurrent;
                }
                do regulateCurrent {
                    in rawCurrent = powerSupply.outputCurrent;
                    in targetCurrent = currentRegulator.targetCurrent;
                    out regulatedCurrent = currentRegulator.regulatedCurrent;
                }
                do deliverDrug {
                    in current = currentRegulator.regulatedCurrent;
                    inout deliveredDosage = treatmentController.deliveredDosage;
                }
                do measureImpedance {
                    out impedance = impedanceSensor.measuredImpedance;
                }
                do checkSafety {
                    in current = currentRegulator.regulatedCurrent;
                    in impedance = impedanceSensor.measuredImpedance;
                    in elapsedTime = safetyMonitor.elapsedTreatmentTime;
                    out fault = safetyMonitor.faultActive;
                }
            }
            accept when treatmentController.deliveredDosage >= treatmentController.targetDosage
                do send new TreatmentCompleteSignal() to treatmentController
                then complete;
            
            accept when safetyMonitor.faultActive
                do send new FaultSignal() to treatmentController
                then fault;
            
            state complete {
                entry stopCurrent;
            }
            accept ResetSignal
                then idle;
            
            state fault {
                entry terminateTreatment;
            }
            accept ResetSignal
                then idle;
        }
    }
    
    part patient : Patient;
    
    flow of current : ElectricCurrent
        from device.activeElectrode.electrodePort.current
        to patient.activeSite.current;
    
    flow of current : ElectricCurrent
        from patient.returnSite.current
        to device.returnElectrode.electrodePort.current;
    
    flow of drug : IonizedDrug
        from device.activeElectrode.drugReservoir.drug
        to device.activeElectrode.drugOut.drug;
    
    requirement def SafeCurrentLimit {
        text "The therapeutic current must be maintained between 2 and 4 milliamperes during active delivery.";
        subject device : IontophoresisDevice;
        attribute minCurrent : ElectricCurrent = 2 [mA];
        attribute maxCurrent : ElectricCurrent = 4 [mA];
        require {
            device.currentRegulator.regulatedCurrent >= minCurrent and
            device.currentRegulator.regulatedCurrent <= maxCurrent
        }
    }
    
    requirement def DosageAccuracy {
        text "The system must automatically stop delivery once the prescribed dosage has been administered.";
        subject reservoir : DrugReservoir;
        require {
            reservoir.deliveredDosage == reservoir.targetDosage
        }
    }
    
    requirement def ImpedanceMonitoring {
        text "The skin impedance must be within a safe range to ensure good electrode contact and prevent skin irritation.";
        subject sensor : ImpedanceSensor;
        attribute minImpedance : ElectricalResistanceValue = 1000 [Ohm];
        attribute maxImpedance : ElectricalResistanceValue = 100000 [Ohm];
        require {
            sensor.measuredImpedance > minImpedance and
            sensor.measuredImpedance < maxImpedance
        }
    }
    
    requirement def MaxTreatmentTime {
        text "The total treatment time must not exceed a predefined safety limit.";
        subject monitor : SafetyMonitor;
        attribute limit : DurationValue = 3600 [s];
        require {
            monitor.elapsedTreatmentTime <= limit
        }
    }
    
    requirement def FaultHandling {
        text "If an unsafe condition is detected, the system must enter a fault state and immediately terminate treatment.";
        subject device : IontophoresisDevice;
        require {
            device.safetyMonitor.faultActive == false or
            device.treatmentController.treatmentActive == false
        }
    }
}
