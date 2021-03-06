#Необходимость: высокая частота обращения к таблице через функцию run_over
#B-t индекс поскольку вставка имеет такуюже частотоу, что и поиск
#могут выполнятся сравнения на < \ >, что не допустимо для hash table
CREATE INDEXT проживание_би_вв ON Проживание (Бандит_id, времяВыселения)

#Необходимость: высокая частота обращения к таблице через функцию захвата территории
#H-t индекс поскольку не предполагается операция сравнения на < \ >
CREATE INDEXT инвентар_пи ON Инвентарь USING hash(Предмет_id)

#Необходимость: частое обращение к таблицы для взятия значения
#H-t индекс поскольку не предполагается операция сравнения на < \ > 
#заинтересованность в быстром получении информации о респе
CREATE INDEXT блок_р ON Блок USING hash(респа)

#Необходимость: частое обращение к таблицы для взятия значения, поскольку бандит - основная единица предметной области
#H-t индекс поскольку не предполагается операция сравнения на < \ > 
#частое использование функций взятия значения в большенстве функций
CREATE INDEXT блок_би ON Блок USING hash(Бандит_id)

#Необходимость: частое обращение к таблицы для взятия значения и вставки
#H-t индекс поскольку не предполагается операция сравнения на < \ > 
#частота взятие значения соразмерна вставке 
CREATE INDEXT предмет_тпи ON Блок USING hash(типПредмета_id)

#Необходимость: высокая частота обращения к таблице через функцию run_over
#B-t индекс поскольку вставка имеет такуюже частотоу, что и поиск
#могут выполнятся сравнения на < \ >, что не допустимо для hash table
CREATE INDEXT проживание_беи_вв ON Блок (Блок_ЕдиницаТерритории_id, времяВыселения)

#Необходимость: частое обращение к таблицы для взятия значения и вставки через функцию захвата
#H-t индекс поскольку не предполагается операция сравнения на < \ > 
#взятие значения и вставка производятся в одной функции
CREATE INDEXT попытка_ии ON Попытка (Инициатор_id)