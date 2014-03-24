require './api'
require './exp'
require './monster'

class GameData
  def initialize
    @exp_table = Exp.new
    @monster = Monster.new
    @floors = {
      1 => {'name' => '寒霜冰川', 'requireFloor' => 8, 'scene' => 'WATER', 'stages' => {}},
      2 => {'name' => '熾熱荒土', 'requireFloor' => 11, 'scene' => 'FIRE', 'stages' => {}},
      3 => {'name' => '神木森林', 'requireFloor' => 14, 'scene' => 'EARTH', 'stages' => {}},
      4 => {'name' => '聖光之城', 'requireFloor' => 17, 'scene' => 'LIGHT', 'stages' => {}},
      5 => {'name' => '暗夜深淵', 'requireFloor' => 20, 'scene' => 'DARK', 'stages' => {}},
      6 => {'name' => '以諾塔', 'scene' => 'TOWER', 'stages' => {}},
      7 => {'name' => '古神遺跡', 'requireFloor' => 23, 'scene' => 'SPECIAL', 'stages' => {}},
      8 => {'name' => '旅人的記憶', 'requireFloor' => 88, 'scene' => 'STORY', 'stages' => {}},
      9 => {'name' => '布蘭克洞窟', 'scene' => 'SPECIAL', 'stages' => {}}
    }
    @floors.each do |index, zone|
      zone['name'] = attribute_color(zone['name'],index.to_i) if zone['name']
    end
    @floor_data = {}
    @bonus_type = {
      0 => 'NONE',
      1 => '體力消耗減 50%',
      2 => '封印卡掉落率 200%',
      3 => 'Exp 獲得量 200%',
      4 => 'RARE_APPEAR',
      5 => '碎片掉落 200%',
      6 => 'REWARD',
      7 => 'ALERT'
    }
    @items = {
      1 => '白羊宮碎片',
      2 => '金牛宮碎片',
      3 => '雙子宮碎片',
      4 => '巨蟹宮碎片',
      5 => '獅子宮碎片',
      6 => '獅子宮碎片',
      7 => '天秤宮碎片',
      8 => '天蠍宮碎片',
      9 => '人馬宮碎片',
      10 => '山羊宮碎片',
      11 => '水瓶宮碎片',
      12 => '雙魚宮碎片'
    }
    @stage_require_floor = {
      '8' => 23, # 一封
      '9' => 28,
      '10' => 33,
      '11' => 38,
      '12' => 43,
      '13' => 48,
      '14' => 53, # 二封
      '15' => 58,
      '16' => 63,
      '17' => 68,
      '18' => 73,
      '19' => 78,
      '20' => 83, # 三封
      '21' => 88,
      '22' => 93,
      '23' => 98,
      '24' => 103,
      '25' => 108,
      '26' => 113, # 四封
      '27' => 118,
      '28' => 123,
      '29' => 128,
      '30' => 133,
      '31' => 138,
      '32' => 143, # 五封
      '87' => 148,
      '88' => 281,
      '89' => 286,
      '90' => 291,
      '91' => 296,
      '92' => 301 # 六封
    }
  end

  def next_exp(level)
    @exp_table.data[level.to_i + 1]
  end

  def set_ratio(monster)
    default_ratio = monster['level'].to_f / monster['maxLevel'].to_f
    case monster['type'].to_i
    when 2 # monster
      default_ratio = default_ratio ** 0.6666667
    when 3, 5 # fairy
      default_ratio = default_ratio ** 1.5
    end
    monster['ratio'] = default_ratio
  end

  def set_hp(monster)
    monster['hp'] = (monster['minCardHP'].to_i + ((monster['maxCardHP'].to_i - monster['minCardHP'].to_i) * monster['ratio'])).to_i
  end

  def set_attack(monster)
    monster['attack'] = (monster['minCardAttack'].to_i + ((monster['maxCardAttack'].to_i - monster['minCardAttack'].to_i) * monster['ratio'])).to_i
  end

  def set_recover(monster)
    monster['recover'] = (monster['minCardRecover'].to_i + ((monster['maxCardRecover'].to_i - monster['minCardRecover'].to_i) * monster['ratio'])).to_i
  end

  def monsters(ids)
    monsters = []
    ids.each do |id|
      monsters << self.monster(id)
    end
    monsters
  end

  def monster(id, level = 1, skillLevel = 1, extras = {})
    return nil if id.to_i == 0
    extras = {} unless extras
    monster = @monster.data[id.to_i].clone
    monster['level'] = level
    monster['skillLevel'] = skillLevel

    monster['coolDown'] = monster['normalSkill']['maxCoolDown'].to_i - skillLevel.to_i + 1

    set_ratio(monster)
    set_hp(monster)
    set_attack(monster)
    set_recover(monster)

    monster['enemyHP'] = extras['HP'] || monster['minEnemyHP'].to_i + (level.to_i * monster['incEnemyHP'].to_i)
    monster['enemyAttack'] = extras['attack'] || monster['minEnemyAttack'].to_i + (level.to_i * monster['incEnemyAttack'].to_i)
    monster['enemyDefense'] = extras['defense'] || monster['minEnemyDefense'].to_i + (level.to_i * monster['incEnemyDefense'].to_i)

    monster['exp'] = monster['baseMergeExp'].to_i + (monster['incMergeExp'].to_i * (monster['level'].to_i - 1) )
    monster['sameAttrExp'] = (monster['exp'] * 1.5).to_i

    monster
  end

  def update_monster(res_json)
    @monster.parse_normal_skill(res_json['data']['normalSkills']) if res_json['data']['normalSkills']
    @monster.parse_data(res_json['data']['monsters']) if res_json['data']['monsters']
  end

  def bonus_type(id)
    @bonus_type[id.to_i]
  end

  def item(id)
    @items[id.to_i]
  end

  def floors
    @floors
  end

  def update_floors(res_json, guild = false)
    return unless res_json['data']['stageList'] or res_json['data']['floorList']
    @floor_data = {}
    stageBonus_data = res_json['data']['stageBonus']
    stages = {}
    res_json['data']['stageList'].each do |stage|
      stage_data = stage.split('|')
      stages[stage_data[0].to_i] = {
        'id' => stage_data[0],
        'zoneId' => stage_data[3],
        'name' => stage_data[9],
        'start_at' => stage_data[7],
        'end_at' => stage_data[8],
        'floors' => {}
      }
    end
    stageBonus_data['stages'].each do |bonus|
      bonus['bonusType_s'] = self.bonus_type bonus['bonusType']
      stages[bonus['stageId'].to_i]['bonus'] = bonus
    end
    res_json['data']['floorList'].each do |floor|
      floor_data = floor.split('|')
      stage = stages[floor_data[1].to_i]
      stamina = floor_data[4].to_i
      stamina = (stamina / 2.0).round if stage['bonus'] and stage['bonus']['bonusType'].to_i == 1
      temp_floor = {
        'id' => floor_data[0],
        'zoneId' => stages[floor_data[1].to_i]['zoneId'],
        'stageId' => floor_data[1],
        'name' => floor_data[7],
        'stamina' => stamina,
        'wave' => floor_data[5]
      }
      stage['floors'][temp_floor['id'].to_i] = temp_floor
      @floor_data[temp_floor['id'].to_i] = temp_floor
    end
    stages.each do |index, stage|
      @floors[stage['zoneId'].to_i]['stages'][index] = stage
    end
    @floors[stageBonus_data['zone'].to_i]['bonus'] = stageBonus_data
    @floors.delete 9 unless guild

    return unless res_json['data']['stageBonus']
  end

  def find_floor_by(id)
    @floor_data[id.to_i]
  end
end
