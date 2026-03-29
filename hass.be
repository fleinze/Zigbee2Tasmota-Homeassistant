#needs the following command to make the payload compatible with home assistant:
#setoption83 1
#only works for temperature, humidity and power sensors. Does not report relay state, does not receive commands from hass
import zigbee
import json
import string
import mqtt
var sensor = {}
for device: zigbee
  var info = device.info()
  var ins = {}
  for i: 0..info.size()-1
    if info[i].key == 'Temperature'  
      ins.insert('Temperature',info[i].val)
    end
    if info[i].key == 'Humidity'
      ins.insert('Humidity',info[i].val)
    end
    if info[i].key == 'RMSVoltage'
      ins.insert('Voltage',info[i].val)
      ins.insert('Current',0)
    end
    if info[i].key == 'ActivePower'
      ins.insert('Power',info[i].val)
      ins.insert('Total',0)
    end
  end
  if ins.size() > 0
     sensor.insert(device.name,ins)
  end
end

# Key-Mapping: Z2T Attributname -> HA-kompatibler Name
# Konflikt: ActivePower gewinnt über Power (Schaltzustand)
var KEY_MAP = {
  'Temperature':  'Temperature',
  'Humidity':     'Humidity',
  'RMSVoltage':   'Voltage',
  'RMSCurrent':   'Current',
  'ActivePower':  'Power',
  'CurrentSummationDelivered': 'Total',
}

var MAC = string.tr(tasmota.wifi()['mac'], ':', '')

class zb_hass_handler
  def attributes_final(event_type, frame, attr_list, idx)
    var out = {}

    # Zweiter Pass: Keys mappen
    for i: 0..attr_list.size()-1
      var k = attr_list[i].key
      var v = attr_list[i].val

      if KEY_MAP.contains(k)
        if k == 'CurrentSummationDelivered'
          out.insert('Total', int(v) / 1000.0)
        else
          out.insert(KEY_MAP[k], v)
        end
      end
    end

    if out.size() == 0  return  end

    var name = zigbee[idx].name
    var payload = {
      'Time': tasmota.time_str(tasmota.rtc()['local']),
    }
    payload.insert(name, out)

    mqtt.publish(
      f'tele/tasmota_{MAC[6..]}/SENSOR',
      json.dump(payload)
    )
  end
end

mqtt.publish(f'tasmota/discovery/{MAC}/sensors', f'{{"sn":{{"Time":"{ tasmota.time_str(tasmota.rtc()["local"]) }",{json.dump(sensor)[1..-2]},"TempUnit":"C"}},"ver":1}}',1)

var hass_handler = zb_hass_handler()
zigbee.add_handler(hass_handler)
