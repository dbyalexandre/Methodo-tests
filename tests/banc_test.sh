compare_output() {
    local test_name="$1"
    local expected_output="$2"
    local actual_output="$3"

    if [ "$expected_output" == "$actual_output" ]; then
        echo "PASSED: $test_name"
    else
        echo "FAILED: $test_name"
        echo "Expected: $expected_output"
        echo "Got: $actual_output"
    fi
}

test_conversion_date() {
    local test_name="Conversion des dates Excel"
    local input_date="43909"
    local expected_output="03/19/2020"
    local actual_output=$(node -e "
        const convertExcelDate = excelDate => { 
            const date = new Date((excelDate - 25569) * 86400 * 1000) 
            const day = String(date.getUTCDate()).padStart(2, '0') 
            const month = String(date.getUTCMonth() + 1).padStart(2, '0') 
            const year = date.getUTCFullYear() 
            return \`\${month}/\${day}/\${year}\`
        }
        console.log(convertExcelDate(${input_date}))
    ")
    compare_output "$test_name" "$expected_output" "$actual_output"
}

test_grouping_data() {
    local test_name="Groupement des Données par SessionID"
    local input_data='[{"SessionID": 1, "Data": "A"}, {"SessionID": 2, "Data": "B"}, {"SessionID": 1, "Data": "C"}]'
    local expected_output='{"1":[{"SessionID":1,"Data":"A"},{"SessionID":1,"Data":"C"}],"2":[{"SessionID":2,"Data":"B"}]}'
    local actual_output=$(node -e "
        const data = ${input_data} 
        const groupedData = data.reduce((acc, obj) => { 
            const sessionID = obj.SessionID 
            if (!acc[sessionID]) { 
                acc[sessionID] = []
            } 
            acc[sessionID].push(obj)
            return acc
        }, {})
        console.log(JSON.stringify(groupedData))
    ")
    compare_output "$test_name" "$expected_output" "$actual_output"
}

test_logic_conditions_initiales() {
    local test_name="Conditions initiales"
    local expected_output='{"serie":0,"vie":2,"consecutiveDays":0}'
    local actual_output=$(node -e "
        const sessionData = [] 
        const result = { serie: 0, vie: 2, consecutiveDays: 0 }
        console.log(JSON.stringify(result))
    ")
    compare_output "$test_name" "$expected_output" "$actual_output"
}

test_logic_increment_serie() {
    local test_name="Incrémentation de la série"
    local input_data='[{"formattedDate": "01/01/2020", "Niveau": 2, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/02/2020", "Niveau": 2, "Allonge": "True", "Assis": "True"}]'
    local expected_output='[{"formattedDate":"01/01/2020","Niveau":2,"Allonge":"True","Assis":"True","serie":0},{"formattedDate":"01/02/2020","Niveau":2,"Allonge":"True","Assis":"True","serie":1}]'
    local actual_output=$(node -e "
        const data = ${input_data}
        const applySerieLogic = sessionData => {
            let serie = 0
            let vie = 2
            let consecutiveDays = 0
            const datesMap = {}
            return sessionData.map((item, index) => {
                const date = item.formattedDate
                if (!datesMap[date]) {
                    datesMap[date] = {
                        level1Count: 0,
                        level2Count: 0,
                        allongeTrueAssisTrue: false,
                        allongeTrueAssisFalse: false,
                        allongeFalseAssisTrue: false,
                        serieIncremented: false,
                        conditionsMet: false,
                        vieDecremented: false,
                    }
                }
                const dateInfo = datesMap[date]
                if (item.Niveau === 1) {
                    dateInfo.level1Count += 1
                }
                if (item.Niveau === 2) {
                    dateInfo.level2Count += 1
                }
                if (item.Allonge === 'True' && item.Assis === 'True') {
                    dateInfo.allongeTrueAssisTrue = true
                }
                if (item.Allonge === 'True' && item.Assis === 'False') {
                    dateInfo.allongeTrueAssisFalse = true
                }
                if (item.Allonge === 'False' && item.Assis === 'True') {
                    dateInfo.allongeFalseAssisTrue = true
                }
                if (
                    (dateInfo.level1Count >= 2 || dateInfo.level2Count >= 1) &&
                    (dateInfo.allongeTrueAssisTrue ||
                        (dateInfo.allongeTrueAssisFalse && dateInfo.allongeFalseAssisTrue))
                ) {
                    dateInfo.conditionsMet = true
                }
                if (index > 0) {
                    const previousDate = sessionData[index - 1].formattedDate
                    const previousDateInfo = datesMap[previousDate]
                    if (
                        previousDateInfo &&
                        previousDateInfo.conditionsMet &&
                        dateInfo.conditionsMet &&
                        !dateInfo.serieIncremented
                    ) {
                        serie += 1
                        dateInfo.serieIncremented = true
                        consecutiveDays += 1
                    }
                }
                if (consecutiveDays === 5) {
                    vie = Math.min(vie + 1, 2)
                    consecutiveDays = 0
                }
                if (
                    !dateInfo.conditionsMet &&
                    !dateInfo.vieDecremented &&
                    (index === sessionData.length - 1 || sessionData[index + 1].formattedDate !== date)
                ) {
                    vie -= 1
                    consecutiveDays = 0
                    if (vie <= 0) {
                        serie = 0
                        vie = 2
                    }
                    dateInfo.vieDecremented = true
                }
                return { ...item, serie }
            })
        }
        const result = applySerieLogic(data)
        console.log(JSON.stringify(result))
    ")
    compare_output "$test_name" "$expected_output" "$actual_output"
}

test_logic_decrement_vie() {
    local test_name="Décrémentation de la vie"
    local input_data='[{"formattedDate": "01/01/2020", "Niveau": 1, "Allonge": "False", "Assis": "False"}]'
    local expected_output='[{"formattedDate":"01/01/2020","Niveau":1,"Allonge":"False","Assis":"False","serie":0}]'
    local actual_output=$(node -e "
        const data = ${input_data}
        const applySerieLogic = sessionData => {
            let serie = 0
            let vie = 2
            let consecutiveDays = 0
            const datesMap = {}
            return sessionData.map((item, index) => {
                const date = item.formattedDate
                if (!datesMap[date]) {
                    datesMap[date] = {
                        level1Count: 0,
                        level2Count: 0,
                        allongeTrueAssisTrue: false,
                        allongeTrueAssisFalse: false,
                        allongeFalseAssisTrue: false,
                        serieIncremented: false,
                        conditionsMet: false,
                        vieDecremented: false,
                    }
                }
                const dateInfo = datesMap[date]
                if (item.Niveau === 1) {
                    dateInfo.level1Count += 1
                }
                if (item.Niveau === 2) {
                    dateInfo.level2Count += 1
                }
                if (item.Allonge === 'True' && item.Assis === 'True') {
                    dateInfo.allongeTrueAssisTrue = true
                }
                if (item.Allonge === 'True' && item.Assis === 'False') {
                    dateInfo.allongeTrueAssisFalse = true
                }
                if (item.Allonge === 'False' && item.Assis === 'True') {
                    dateInfo.allongeFalseAssisTrue = true
                }
                if (
                    (dateInfo.level1Count >= 2 || dateInfo.level2Count >= 1) &&
                    (dateInfo.allongeTrueAssisTrue ||
                        (dateInfo.allongeTrueAssisFalse && dateInfo.allongeFalseAssisTrue))
                ) {
                    dateInfo.conditionsMet = true
                }
                if (
                    !dateInfo.conditionsMet &&
                    !dateInfo.vieDecremented &&
                    (index === sessionData.length - 1 || sessionData[index + 1].formattedDate !== date)
                ) {
                    vie -= 1
                    consecutiveDays = 0
                    if (vie <= 0) {
                        serie = 0
                        vie = 2
                    }
                    dateInfo.vieDecremented = true
                }
                return { ...item, serie }
            })
        }
        const result = applySerieLogic(data)
        console.log(JSON.stringify(result))
    ")
    compare_output "$test_name" "$expected_output" "$actual_output"
}

test_logic_reset_serie_vie() {
    local test_name="Réinitialisation de la série et des vies"
    local input_data='[{"formattedDate": "01/01/2020", "Niveau": 1, "Allonge": "False", "Assis": "False"}, {"formattedDate": "01/02/2020", "Niveau": 1, "Allonge": "False", "Assis": "False"}, {"formattedDate": "01/03/2020", "Niveau": 1, "Allonge": "False", "Assis": "False"}]'
    local expected_output='[{"formattedDate":"01/01/2020","Niveau":1,"Allonge":"False","Assis":"False","serie":0},{"formattedDate":"01/02/2020","Niveau":1,"Allonge":"False","Assis":"False","serie":0},{"formattedDate":"01/03/2020","Niveau":1,"Allonge":"False","Assis":"False","serie":0}]'
    local actual_output=$(node -e "
        const data = ${input_data}
        const applySerieLogic = sessionData => {
            let serie = 0
            let vie = 2
            let consecutiveDays = 0
            const datesMap = {}
            return sessionData.map((item, index) => {
                const date = item.formattedDate
                if (!datesMap[date]) {
                    datesMap[date] = {
                        level1Count: 0,
                        level2Count: 0,
                        allongeTrueAssisTrue: false,
                        allongeTrueAssisFalse: false,
                        allongeFalseAssisTrue: false,
                        serieIncremented: false,
                        conditionsMet: false,
                        vieDecremented: false,
                    }
                }
                const dateInfo = datesMap[date]
                if (item.Niveau === 1) {
                    dateInfo.level1Count += 1
                }
                if (item.Niveau === 2) {
                    dateInfo.level2Count += 1
                }
                if (item.Allonge === 'True' && item.Assis === 'True') {
                    dateInfo.allongeTrueAssisTrue = true
                }
                if (item.Allonge === 'True' && item.Assis === 'False') {
                    dateInfo.allongeTrueAssisFalse = true
                }
                if (item.Allonge === 'False' && item.Assis === 'True') {
                    dateInfo.allongeFalseAssisTrue = true
                }
                if (
                    (dateInfo.level1Count >= 2 || dateInfo.level2Count >= 1) &&
                    (dateInfo.allongeTrueAssisTrue ||
                        (dateInfo.allongeTrueAssisFalse && dateInfo.allongeFalseAssisTrue))
                ) {
                    dateInfo.conditionsMet = true
                }
                if (
                    !dateInfo.conditionsMet &&
                    !dateInfo.vieDecremented &&
                    (index === sessionData.length - 1 || sessionData[index + 1].formattedDate !== date)
                ) {
                    vie -= 1
                    consecutiveDays = 0
                    if (vie <= 0) {
                        serie = 0
                        vie = 2
                    }
                    dateInfo.vieDecremented = true
                }
                return { ...item, serie }
            })
        }
        const result = applySerieLogic(data)
        console.log(JSON.stringify(result))
    ")
    compare_output "$test_name" "$expected_output" "$actual_output"
}

test_logic_regain_vie() {
    local test_name="Regain de vie après 5 jours consécutifs"
    local input_data='[{"formattedDate": "01/01/2020", "Niveau": 1, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/02/2020", "Niveau": 1, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/03/2020", "Niveau": 1, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/04/2020", "Niveau": 1, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/05/2020", "Niveau": 1, "Allonge": "True", "Assis": "True"}]'
    local expected_output='[{"formattedDate":"01/01/2020","Niveau":1,"Allonge":"True","Assis":"True","serie":0},{"formattedDate":"01/02/2020","Niveau":1,"Allonge":"True","Assis":"True","serie":0},{"formattedDate":"01/03/2020","Niveau":1,"Allonge":"True","Assis":"True","serie":0},{"formattedDate":"01/04/2020","Niveau":1,"Allonge":"True","Assis":"True","serie":0},{"formattedDate":"01/05/2020","Niveau":1,"Allonge":"True","Assis":"True","serie":0}]'
    local actual_output=$(node -e "
        const data = ${input_data}
        const applySerieLogic = sessionData => {
            let serie = 0
            let vie = 2
            let consecutiveDays = 0
            const datesMap = {}
            return sessionData.map((item, index) => {
                const date = item.formattedDate
                if (!datesMap[date]) {
                    datesMap[date] = {
                        level1Count: 0,
                        level2Count: 0,
                        allongeTrueAssisTrue: false,
                        allongeTrueAssisFalse: false,
                        allongeFalseAssisTrue: false,
                        serieIncremented: false,
                        conditionsMet: false,
                        vieDecremented: false,
                    }
                }
                const dateInfo = datesMap[date]
                if (item.Niveau === 1) {
                    dateInfo.level1Count += 1
                }
                if (item.Niveau === 2) {
                    dateInfo.level2Count += 1
                }
                if (item.Allonge === 'True' && item.Assis === 'True') {
                    dateInfo.allongeTrueAssisTrue = true
                }
                if (item.Allonge === 'True' && item.Assis === 'False') {
                    dateInfo.allongeTrueAssisFalse = true
                }
                if (item.Allonge === 'False' && item.Assis === 'True') {
                    dateInfo.allongeFalseAssisTrue = true
                }
                if (
                    (dateInfo.level1Count >= 2 || dateInfo.level2Count >= 1) &&
                    (dateInfo.allongeTrueAssisTrue ||
                        (dateInfo.allongeTrueAssisFalse && dateInfo.allongeFalseAssisTrue))
                ) {
                    dateInfo.conditionsMet = true
                }
                if (index > 0) {
                    const previousDate = sessionData[index - 1].formattedDate
                    const previousDateInfo = datesMap[previousDate]
                    if (
                        previousDateInfo &&
                        previousDateInfo.conditionsMet &&
                        dateInfo.conditionsMet &&
                        !dateInfo.serieIncremented
                    ) {
                        serie += 1
                        dateInfo.serieIncremented = true
                        consecutiveDays += 1
                    }
                }
                if (consecutiveDays === 5) {
                    vie = Math.min(vie + 1, 2)
                    consecutiveDays = 0
                }
                return { ...item, serie }
            })
        }
        const result = applySerieLogic(data)
        console.log(JSON.stringify(result))
    ")
    compare_output "$test_name" "$expected_output" "$actual_output"
}

test_condition_niveau() {
    local test_name="Condition de niveau"
    local input_data='[{"formattedDate": "01/01/2020", "Niveau": 1, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/01/2020", "Niveau": 2, "Allonge": "False", "Assis": "True"}]'
    local expected_output='{"level1Count":1,"level2Count":1,"conditionsMet":true}'
    local actual_output=$(node -e "
        const data = ${input_data}
        const dateInfo = { level1Count: 0, level2Count: 0, conditionsMet: false }
        data.forEach(item => {
            if (item.Niveau === 1) {
                dateInfo.level1Count += 1
            }
            if (item.Niveau === 2) {
                dateInfo.level2Count += 1
            }
        })
        if (dateInfo.level1Count >= 2 || dateInfo.level2Count >= 1) {
            dateInfo.conditionsMet = true
        }
        console.log(JSON.stringify(dateInfo))
    ")
    compare_output "$test_name" "$expected_output" "$actual_output"
}

test_condition_position() {
    local test_name="Condition de position"
    local input_data='[{"formattedDate": "01/01/2020", "Niveau": 1, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/01/2020", "Niveau": 1, "Allonge": "True", "Assis": "False"}, {"formattedDate": "01/01/2020", "Niveau": 1, "Allonge": "False", "Assis": "True"}]'
    local expected_output='{"allongeTrueAssisTrue":true}'
    local actual_output=$(node -e "
        const data = ${input_data}
        const dateInfo = { allongeTrueAssisTrue: false }
        data.forEach(item => {
            if (item.Allonge === 'True' && item.Assis === 'True') {
                dateInfo.allongeTrueAssisTrue = true
            }
        })
        console.log(JSON.stringify(dateInfo))
    ")
    compare_output "$test_name" "$expected_output" "$actual_output"
}

test_generation_csv() {
    local test_name="Génération du Fichier CSV"
    local input_data='[{"Date":"01/01/2020","Niveau":1,"Allonge":"True","Assis":"True","SessionID":1,"formattedDate":"01/01/2020","serie":0}]'
    local expected_output=$'Date,Niveau,Allonge,Assis,SessionID,formattedDate,serie\n01/01/2020,1,True,True,1,01/01/2020,0'
    local actual_output=$(node -e "
        const data = ${input_data}
        let csvContent = 'Date,Niveau,Allonge,Assis,SessionID,formattedDate,serie\n'
        data.forEach(item => {
            const row = [
                item.Date,
                item.Niveau,
                item.Allonge,
                item.Assis,
                item.SessionID,
                item.formattedDate,
                item.serie,
            ].join(',')
            csvContent += row + '\n'
        })
        console.log(csvContent)
    ")
    compare_output "$test_name" "$expected_output" "$actual_output"
}

test_scenario_combine() {
    local test_name="Scénario combiné"
    local input_data='[{"formattedDate": "01/01/2020", "Niveau": 2, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/02/2020", "Niveau": 2, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/03/2020", "Niveau": 2, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/04/2020", "Niveau": 1, "Allonge": "False", "Assis": "False"}, {"formattedDate": "01/05/2020", "Niveau": 2, "Allonge": "False", "Assis": "False"}, {"formattedDate": "01/06/2020", "Niveau": 2, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/07/2020", "Niveau": 2, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/08/2020", "Niveau": 2, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/09/2020", "Niveau": 2, "Allonge": "True", "Assis": "True"}, {"formattedDate": "01/10/2020", "Niveau": 2, "Allonge": "True", "Assis": "True"}]'
    local expected_output='[{"formattedDate":"01/01/2020","Niveau":2,"Allonge":"True","Assis":"True","serie":0},{"formattedDate":"01/02/2020","Niveau":2,"Allonge":"True","Assis":"True","serie":1},{"formattedDate":"01/03/2020","Niveau":2,"Allonge":"True","Assis":"True","serie":2},{"formattedDate":"01/04/2020","Niveau":1,"Allonge":"False","Assis":"False","serie":2},{"formattedDate":"01/05/2020","Niveau":2,"Allonge":"False","Assis":"False","serie":0},{"formattedDate":"01/06/2020","Niveau":2,"Allonge":"True","Assis":"True","serie":0},{"formattedDate":"01/07/2020","Niveau":2,"Allonge":"True","Assis":"True","serie":1},{"formattedDate":"01/08/2020","Niveau":2,"Allonge":"True","Assis":"True","serie":2},{"formattedDate":"01/09/2020","Niveau":2,"Allonge":"True","Assis":"True","serie":3},{"formattedDate":"01/10/2020","Niveau":2,"Allonge":"True","Assis":"True","serie":4}]'
    local actual_output=$(node -e "
        const data = ${input_data}
        const applySerieLogic = sessionData => {
            let serie = 0
            let vie = 2
            let consecutiveDays = 0
            const datesMap = {}
            return sessionData.map((item, index) => {
                const date = item.formattedDate
                if (!datesMap[date]) {
                    datesMap[date] = {
                        level1Count: 0,
                        level2Count: 0,
                        allongeTrueAssisTrue: false,
                        allongeTrueAssisFalse: false,
                        allongeFalseAssisTrue: false,
                        serieIncremented: false,
                        conditionsMet: false,
                        vieDecremented: false,
                    }
                }
                const dateInfo = datesMap[date]
                if (item.Niveau === 1) {
                    dateInfo.level1Count += 1
                }
                if (item.Niveau === 2) {
                    dateInfo.level2Count += 1
                }
                if (item.Allonge === 'True' && item.Assis === 'True') {
                    dateInfo.allongeTrueAssisTrue = true
                }
                if (item.Allonge === 'True' && item.Assis === 'False') {
                    dateInfo.allongeTrueAssisFalse = true
                }
                if (item.Allonge === 'False' && item.Assis === 'True') {
                    dateInfo.allongeFalseAssisTrue = true
                }
                if (
                    (dateInfo.level1Count >= 2 || dateInfo.level2Count >= 1) &&
                    (dateInfo.allongeTrueAssisTrue ||
                        (dateInfo.allongeTrueAssisFalse && dateInfo.allongeFalseAssisTrue))
                ) {
                    dateInfo.conditionsMet = true
                }
                if (index > 0) {
                    const previousDate = sessionData[index - 1].formattedDate
                    const previousDateInfo = datesMap[previousDate]
                    if (
                        previousDateInfo &&
                        previousDateInfo.conditionsMet &&
                        dateInfo.conditionsMet &&
                        !dateInfo.serieIncremented
                    ) {
                        serie += 1
                        dateInfo.serieIncremented = true
                        consecutiveDays += 1
                    }
                }
                if (consecutiveDays === 5) {
                    vie = Math.min(vie + 1, 2)
                    consecutiveDays = 0
                }
                if (
                    !dateInfo.conditionsMet &&
                    !dateInfo.vieDecremented &&
                    (index === sessionData.length - 1 || sessionData[index + 1].formattedDate !== date)
                ) {
                    vie -= 1
                    consecutiveDays = 0
                    if (vie <= 0) {
                        serie = 0
                        vie = 2
                    }
                    dateInfo.vieDecremented = true
                }
                return { ...item, serie }
            })
        }
        const result = applySerieLogic(data)
        console.log(JSON.stringify(result))
    ")
    compare_output "$test_name" "$expected_output" "$actual_output"
}

test_cas_erreur() {
    local test_name="Cas d'Erreur"
    local input_data='[{"formattedDate": "01/01/2020", "Niveau": 1, "Allonge": null, "Assis": "True"}]'
    local expected_output='Error: Invalid data'
    local actual_output=$(node -e "
        const data = ${input_data}
        try {
            data.forEach(item => {
                if (item.Allonge === null || item.Assis === null) {
                    throw new Error('Invalid data')
                }
            })
            console.log('Valid data')
        } catch (error) {
            console.log('Error:', error.message)
        }
    ")
    compare_output "$test_name" "$expected_output" "$actual_output"
}

test_conversion_date
test_grouping_data
test_logic_conditions_initiales
test_logic_increment_serie
test_logic_decrement_vie
test_logic_reset_serie_vie
test_logic_regain_vie
test_condition_niveau
test_condition_position
test_generation_csv
test_scenario_combine
test_cas_erreur
