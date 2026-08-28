package PhotomultiplierSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    
    alias Voltage for ISQ::ElectricPotentialValue;
    alias Pressure for ISQ::PressureValue;
    alias Length for ISQ::LengthValue;
    
    item def Photon {
        attribute wavelength : Length;
    }
    item def Photoelectron;
    item def ElectricalPulse {
        attribute amplitude : Voltage;
        attribute duration : ISQ::TimeValue;
    }
    
    attribute def PhotonEvent;
    
    part def BorosilicateWindow {
        attribute material : ScalarValues::String := "Borosilicate Glass";
        in port photonIn : Photon;
        out port photonOut : Photon;
        action transmit {
            in p : Photon;
            out p_out : Photon;
        }
    }
    
    part def Photocathode {
        attribute material : ScalarValues::String := "Bialkali";
        in port photonIn : Photon;
        out port photoelectronOut : Photoelectron;
        action convert {
            in p : Photon;
            out pe : Photoelectron;
        }
    }
    
    part def Dynode {
        attribute stageIndex : ScalarValues::Integer;
        attribute secondaryEmissionFactor : ScalarValues::Real := 4.0;
        in port electronsIn : Photoelectron;
        out port electronsOut : Photoelectron;
        in port hvInput : Voltage;
        action multiply {
            in e_in : Photoelectron;
            out e_out : Photoelectron;
        }
    }
    
    part def Anode {
        in port electronsIn : Photoelectron;
        out port pulseOut : ElectricalPulse;
        action collect {
            in e : Photoelectron;
            out p : ElectricalPulse;
        }
    }
    
    part def VacuumEnvelope {
        attribute vacuumLevel : Pressure;
    }
    
    part def PhotomultiplierTube {
        attribute numberOfDynodes : ScalarValues::Integer := 8;
        attribute totalGain : ScalarValues::Real := 1000000.0;
        
        in port photonInput : Photon;
        out port pulseOutput : ElectricalPulse;
        in port hvInput : Voltage;
        
        part window : BorosilicateWindow;
        part photocathode : Photocathode;
        part dynode1 : Dynode;
        part dynode2 : Dynode;
        part dynode3 : Dynode;
        part dynode4 : Dynode;
        part dynode5 : Dynode;
        part dynode6 : Dynode;
        part dynode7 : Dynode;
        part dynode8 : Dynode;
        part anode : Anode;
        part envelope : VacuumEnvelope;
        
        connect photonInput to window.photonIn;
        connect window.photonOut to photocathode.photonIn;
        connect photocathode.photoelectronOut to dynode1.electronsIn;
        connect dynode1.electronsOut to dynode2.electronsIn;
        connect dynode2.electronsOut to dynode3.electronsIn;
        connect dynode3.electronsOut to dynode4.electronsIn;
        connect dynode4.electronsOut to dynode5.electronsIn;
        connect dynode5.electronsOut to dynode6.electronsIn;
        connect dynode6.electronsOut to dynode7.electronsIn;
        connect dynode7.electronsOut to dynode8.electronsIn;
        connect dynode8.electronsOut to anode.electronsIn;
        connect anode.pulseOut to pulseOutput;
    }
    
    part def HighVoltageSupply {
        attribute outputVoltage : Voltage;
        out port hvOutput : Voltage;
        action regulate {
            out v : Voltage;
        }
    }
    
    part def VoltageDividerNetwork {
        attribute numStages : ScalarValues::Integer := 8;
        in port hvInput : Voltage;
        out port dynode1HV : Voltage;
        out port dynode2HV : Voltage;
        out port dynode3HV : Voltage;
        out port dynode4HV : Voltage;
        out port dynode5HV : Voltage;
        out port dynode6HV : Voltage;
        out port dynode7HV : Voltage;
        out port dynode8HV : Voltage;
        action distribute {
            in hv : Voltage;
        }
    }
    
    part def PreAmplifier {
        attribute gain : ScalarValues::Real := 100.0;
        in port pulseIn : ElectricalPulse;
        out port pulseOut : ElectricalPulse;
        action amplify {
            in p_in : ElectricalPulse;
            out p_out : ElectricalPulse;
        }
    }
    
    part def Discriminator {
        attribute threshold : Voltage;
        in port pulseIn : ElectricalPulse;
        out port validEvent : PhotonEvent;
        action filterNoise {
            in p : ElectricalPulse;
            out e : PhotonEvent;
        }
    }
    
    action def ConvertPhoton {
        in photon : Photon;
        out electron : Photoelectron;
    }
    action def MultiplyElectrons {
        in electronsIn : Photoelectron;
        out electronsOut : Photoelectron;
    }
    action def CollectElectrons {
        in electrons : Photoelectron;
        out pulse : ElectricalPulse;
    }
    action def AmplifyPulse {
        in pulseIn : ElectricalPulse;
        out pulseOut : ElectricalPulse;
    }
    action def FilterPulse {
        in pulse : ElectricalPulse;
        out evt : PhotonEvent;
    }
    action def DetectSinglePhoton {
        in photon : Photon;
        out evt : PhotonEvent;
    }
    
    state def PMTOperation {
        first state idle;
        
        accept Photon
            then state photonDetected;
        
        state photonDetected {
            do action {
                action convert : ConvertPhoton {
                    in photon : Photon;
                    out electron : Photoelectron;
                }
                action multiply1 : MultiplyElectrons {
                    in electronsIn = convert.electron;
                    out electronsOut : Photoelectron;
                }
                action multiply2 : MultiplyElectrons {
                    in electronsIn = multiply1.electronsOut;
                    out electronsOut : Photoelectron;
                }
                action multiply3 : MultiplyElectrons {
                    in electronsIn = multiply2.electronsOut;
                    out electronsOut : Photoelectron;
                }
                action multiply4 : MultiplyElectrons {
                    in electronsIn = multiply3.electronsOut;
                    out electronsOut : Photoelectron;
                }
                action multiply5 : MultiplyElectrons {
                    in electronsIn = multiply4.electronsOut;
                    out electronsOut : Photoelectron;
                }
                action multiply6 : MultiplyElectrons {
                    in electronsIn = multiply5.electronsOut;
                    out electronsOut : Photoelectron;
                }
                action multiply7 : MultiplyElectrons {
                    in electronsIn = multiply6.electronsOut;
                    out electronsOut : Photoelectron;
                }
                action multiply8 : MultiplyElectrons {
                    in electronsIn = multiply7.electronsOut;
                    out electronsOut : Photoelectron;
                }
                action collect : CollectElectrons {
                    in electrons = multiply8.electronsOut;
                    out pulse : ElectricalPulse;
                }
                action amplify : AmplifyPulse {
                    in pulseIn = collect.pulse;
                    out pulseOut : ElectricalPulse;
                }
                action discriminate : FilterPulse {
                    in pulse = amplify.pulseOut;
                    out evt : PhotonEvent;
                }
            }
        }
        then idle;
    }
    
    requirement def PhotomultiplierRequirement {
        attribute targetGain : ScalarValues::Real := 1000000.0;
        attribute operatingVoltage : Voltage;
        attribute dynodeCount : ScalarValues::Integer := 8;
        attribute vacuumLevel : Pressure;
    }
    
    requirement req_SinglePhotonSensitivity : PhotomultiplierRequirement {
        doc /* The PMT shall detect single photons and output a measurable electrical pulse. */
    }
    
    requirement req_HighGain : PhotomultiplierRequirement {
        doc /* The dynode chain shall achieve a total electron multiplication gain of approximately one million. */
        attribute requiredGain : ScalarValues::Real := 1000000.0;
    }
    
    requirement req_HighVoltage : PhotomultiplierRequirement {
        doc /* The high voltage supply shall provide 1200 volts to the voltage divider network. */
        attribute requiredVoltage : Voltage;
    }
    
    requirement req_NoiseFiltering : PhotomultiplierRequirement {
        doc /* The discriminator shall reject electronic noise below the specified threshold. */
        attribute noiseThreshold : Voltage;
    }
    
    requirement req_VacuumIntegrity : PhotomultiplierRequirement {
        doc /* The vacuum envelope shall maintain a vacuum level to ensure unobstructed electron travel. */
        attribute requiredVacuum : Pressure;
    }
    
    part photomultiplierSystem {
        in port photonInput : Photon;
        out port eventOutput : PhotonEvent;
        
        part pmt : PhotomultiplierTube;
        part hvSupply : HighVoltageSupply;
        part divider : VoltageDividerNetwork;
        part preamp : PreAmplifier;
        part disc : Discriminator;
        
        connect photonInput to pmt.photonInput;
        connect hvSupply.hvOutput to divider.hvInput;
        connect divider.dynode1HV to pmt.dynode1.hvInput;
        connect divider.dynode2HV to pmt.dynode2.hvInput;
        connect divider.dynode3HV to pmt.dynode3.hvInput;
        connect divider.dynode4HV to pmt.dynode4.hvInput;
        connect divider.dynode5HV to pmt.dynode5.hvInput;
        connect divider.dynode6HV to pmt.dynode6.hvInput;
        connect divider.dynode7HV to pmt.dynode7.hvInput;
        connect divider.dynode8HV to pmt.dynode8.hvInput;
        connect pmt.pulseOutput to preamp.pulseIn;
        connect preamp.pulseOut to disc.pulseIn;
        connect disc.validEvent to eventOutput;
        
        state operation : PMTOperation;
        
        satisfy req_SinglePhotonSensitivity by pmt;
        satisfy req_HighGain by pmt.dynode1;
        satisfy req_HighVoltage by hvSupply;
        satisfy req_NoiseFiltering by disc;
        satisfy req_VacuumIntegrity by pmt.envelope;
    }
}
