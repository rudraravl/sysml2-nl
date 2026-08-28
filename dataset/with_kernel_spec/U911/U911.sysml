package 'TLD System Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def IssueToPersonnel;
    attribute def BeginExposure;
    attribute def CollectForAnalysis;
    attribute def InsertIntoReader;
    attribute def ReadingComplete;
    attribute def AnnealComplete;
    attribute def BadgeInserted;
    attribute def TempReached;
    attribute def SignalStable;
    attribute def CalculationDone;
    attribute def AnnealCycleDone;
    attribute def RecordSaved;

    attribute def RadiationDose :> Real;
    attribute def TemperatureValue :> Real;
    attribute def LightIntensityValue :> Real;
    attribute def ElectricalSignalValue :> Real;

    item def Radiation;
    item def Light;
    item def ElectricalSignal;

    item def DoseRecord {
        attribute measuredDose : RadiationDose;
        attribute readingTime : String;
        attribute badgeID : String;
    }

    port def RadiationInPort { in radiation : Radiation; }
    port def HeatOutPort { out heat : TemperatureValue; }
    port def HeatInPort { in heat : TemperatureValue; }
    port def LightOutPort { out light : Light; }
    port def LightInPort { in light : Light; }
    port def SignalOutPort { out signal : ElectricalSignal; }
    port def SignalInPort { in signal : ElectricalSignal; }
    port def RecordOutPort { out record : DoseRecord; }
    port def ControlOutPort { out command : String; }

    part def TLDCrystal {
        attribute storedDose : RadiationDose;
        port radiationIn : RadiationInPort;
        port thermalIn : HeatInPort;
        port lightOut : LightOutPort;
    }

    part def DosimeterBadge {
        attribute badgeID : String;
        part crystal : TLDCrystal;
    }

    part def HeatingElement {
        port thermalOut : HeatOutPort;
        attribute currentTemp : TemperatureValue;
    }

    part def PhotomultiplierTube {
        port lightIn : LightInPort;
        port signalOut : SignalOutPort;
        attribute gain : Real;
    }

    part def ControlProcessor {
        port signalIn : SignalInPort;
        port controlOut : ControlOutPort;
        port recordOut : RecordOutPort;
        attribute calibrationFactor : Real;
    }

    part def TLDReader {
        part heater : HeatingElement;
        part pmt : PhotomultiplierTube;
        part processor : ControlProcessor;
        ref part insertedBadge : DosimeterBadge [0..1];

        connect heater.thermalOut to insertedBadge.crystal.thermalIn;
        connect insertedBadge.crystal.lightOut to pmt.lightIn;
        connect pmt.signalOut to processor.signalIn;
    }

    action absorbRadiation { in badge : DosimeterBadge; }
    action heatCrystal { in heater : HeatingElement; in crystal : TLDCrystal; }
    action captureLight { in pmt : PhotomultiplierTube; in crystal : TLDCrystal; }
    action calculateDose { in proc : ControlProcessor; out dose : RadiationDose; }
    action generateRecord { in proc : ControlProcessor; in id : String; out record : DoseRecord; }
    action processAndRecord { in proc : ControlProcessor; in id : String; out dose : RadiationDose; out record : DoseRecord; }
    action annealCrystal { in heater : HeatingElement; in crystal : TLDCrystal; }

    state def BadgeLifecycle;
    state badgeLifecycle : BadgeLifecycle {
        in badge : DosimeterBadge;
        entry; then ready;
        state ready;
        accept IssueToPersonnel then issued;
        state issued;
        accept BeginExposure then accumulating;
        state accumulating {
            do absorbRadiation { in badge = badge; }
        }
        accept CollectForAnalysis then collected;
        state collected;
        accept InsertIntoReader then reading;
        state reading;
        accept ReadingComplete then annealing;
        state annealing;
        accept AnnealComplete then ready;
    }

    state def ReaderOperation;
    state readerOperation : ReaderOperation {
        in reader : TLDReader;
        entry; then idle;
        state idle;
        accept BadgeInserted then heating;
        state heating {
            do heatCrystal { in heater = reader.heater; in crystal = reader.insertedBadge.crystal; }
        }
        accept TempReached then measuring;
        state measuring {
            do captureLight { in pmt = reader.pmt; in crystal = reader.insertedBadge.crystal; }
        }
        accept SignalStable then processing;
        state processing {
            do processAndRecord { in proc = reader.processor; in id = reader.insertedBadge.badgeID; out dose; out record; }
        }
        accept CalculationDone then annealing;
        state annealing {
            do annealCrystal { in heater = reader.heater; in crystal = reader.insertedBadge.crystal; }
        }
        accept AnnealCycleDone then complete;
        state complete;
        accept RecordSaved then idle;
    }

    requirement def MeasureRadiationDose {
        subject badge : DosimeterBadge;
        doc /* The TLD Reader shall measure the cumulative radiation dose stored in the Dosimeter Badge by heating the TLD Crystal and integrating the emitted light. */
    }

    requirement def Reusability {
        subject badge : DosimeterBadge;
        doc /* The TLD Reader shall anneal the TLD Crystal after reading to reset the stored dose to zero for reuse. */
    }

    individual def TestSystem :> TLDReader;
    individual def TestBadge1 :> DosimeterBadge;
    individual def TestBadge2 :> DosimeterBadge;

    individual testSystem : TestSystem {
        timeslice cycle1 {
            ref part :>> insertedBadge : TestBadge1 {
                :>> badgeID = "B001";
                part :>> crystal {
                    :>> storedDose = 1.5;
                }
            }
        }
        then timeslice cycle2 {
            ref part :>> insertedBadge : TestBadge2 {
                :>> badgeID = "B002";
                part :>> crystal {
                    :>> storedDose = 2.0;
                }
            }
        }
    }
}
