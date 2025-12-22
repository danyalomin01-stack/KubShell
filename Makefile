# Компилятор и флаги
CXX ?= g++

# Только флаги компиляции (без -l...)
CPPFLAGS ?= -I/usr/include/fuse3
CXXFLAGS ?= -std=c++20 -Wall -Wextra

# Линковка
LDFLAGS ?= -L/usr/lib/$(DEB_HOST_MULTIARCH)
LDLIBS ?= -lfuse3 -lreadline -lhistory
TARGET = kubsh
TEST_IMAGE ?= my-kubsh:arm
DEB_HOST_MULTIARCH := $(shell dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo aarch64-linux-gnu)

# Версия пакета
ARCH := $(shell dpkg --print-architecture)
VERSION = 1.0.0
PACKAGE_NAME = kubsh
BUILD_DIR = build
DEB_DIR = $(BUILD_DIR)/kubsh_$(VERSION)_$(ARCH)
DEB_FILE := $(CURDIR)/kubsh.deb
DOCKER_PLATFORM := linux/$(ARCH)
# Исходные файлы
SRCS = main.cpp vfs.cpp
OBJS = $(SRCS:.cpp=.o)

# Основные цели
all: deps $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $(TARGET) $(OBJS) $(LDLIBS)

%.o: %.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

# Запуск шелла
run: $(TARGET)
	./$(TARGET)

# Подготовка структуры для deb-пакета
prepare-deb: $(TARGET)
	@echo "Подготовка структуры для deb-пакета..."
	@mkdir -p $(DEB_DIR)/DEBIAN
	@mkdir -p $(DEB_DIR)/usr/local/bin
	@cp $(TARGET) $(DEB_DIR)/usr/local/bin/
	@chmod +x $(DEB_DIR)/usr/local/bin/$(TARGET)

	@echo "Создание control файла..."
	@echo "Package: $(PACKAGE_NAME)" > $(DEB_DIR)/DEBIAN/control
	@echo "Version: $(VERSION)" >> $(DEB_DIR)/DEBIAN/control
	@echo "Section: utils" >> $(DEB_DIR)/DEBIAN/control
	@echo "Priority: optional" >> $(DEB_DIR)/DEBIAN/control
	@echo "Architecture: $(ARCH)" >> $(DEB_DIR)/DEBIAN/control
	@echo "Maintainer: Your Name <your.email@example.com>" >> $(DEB_DIR)/DEBIAN/control
	@echo "Depends: libfuse3-3 | libfuse3-4, libreadline8" >> $(DEB_DIR)/DEBIAN/control
	@echo "Description: Simple custom shell" >> $(DEB_DIR)/DEBIAN/control
	@echo " A simple custom shell implementation for learning purposes." >> $(DEB_DIR)/DEBIAN/control

# Сборка deb-пакета
deb: prepare-deb
	@echo "Сборка deb-пакета..."
	@rm -f $(DEB_FILE)
	@dpkg-deb --build $(DEB_DIR) $(DEB_FILE)
	@echo "Пакет создан: $(DEB_FILE)"

# Быстрая проверка, что зависимости стоят (полезно в VM)
deps:
	@dpkg -s libfuse3-dev >/dev/null 2>&1 || (echo "Не найден libfuse3-dev. Установи: sudo apt update && sudo apt install -y libfuse3-dev" && exit 1)
	@dpkg -s libreadline-dev >/dev/null 2>&1 || (echo "Не найден libreadline-dev. Установи: sudo apt update && sudo apt install -y libreadline-dev" && exit 1)
	@dpkg -s dpkg-dev >/dev/null 2>&1 || (echo "Не найден dpkg-dev. Установи: sudo apt update && sudo apt install -y dpkg-dev" && exit 1)
	@echo "OK: зависимости установлены"

# Установка пакета (требует sudo)
install: deb
	sudo dpkg -i $(DEB_FILE)

# Удаление пакета
uninstall:
	sudo dpkg -r $(PACKAGE_NAME)

# Тестирование в Docker контейнере
test:
	@echo "Запуск теста в Docker"
	@docker run --rm -it \
	  --device /dev/fuse \
	  --cap-add SYS_ADMIN \
	  --security-opt apparmor:unconfined \
	  -v $(PWD):/mnt \
	  kurilovo/my-kubsh:arm \
	  bash -lc '/opt/check.sh'

# Очистка
clean:
	@sudo rm -rf $(BUILD_DIR) $(TARGET) *.deb $(OBJS) 2>/dev/null || true
	@rm -rf $(BUILD_DIR) $(TARGET) *.deb $(OBJS) 2>/dev/null || true


# Показать справку
help:
	@echo "Доступные команды:"
	@echo "  make all      - собрать программу"
	@echo "  make deb      - создать deb-пакет"
	@echo "  make install  - установить пакет"
	@echo "  make uninstall - удалить пакет"
	@echo "  make clean    - очистить проект"
	@echo "  make run      - запустить шелл"
	@echo "  make test     - собрать и запустить тест в Docker"
	@echo "  make help     - показать эту справку"

.PHONY: all deb install uninstall clean help prepare-deb run test deps
